# frozen_string_literal: true

require 'base64'
require 'graphql/client'
require 'graphql/client/http'
require 'json'
require 'kramdown'
require 'twingly/url/utilities'

module BountyTargets
  class Hackerone
    include Retryable

    def initialize
      schema
    end

    def scan
      return @scan_results if instance_variable_defined?(:@scan_results)

      @scan_results = directory_index.map do |program|
        in_scope, out_of_scope = program_targets(program)
        program.merge(
          'targets' => {
            'in_scope' => in_scope,
            'out_of_scope' => out_of_scope
          }
        )
      end
    end

    def directory_index
      after = nil
      programs = []

      Kernel.loop do
        page = nil
        retryable do
          page = @graphql_client.query(@directory_query, variables: {after: after})
          raise StandardError, page.errors.details.inspect unless page.errors.details.empty?

          programs.concat(page.data.teams.nodes.map do |node|
            id = Base64.decode64(node.id).gsub(%r{^gid://hackerone/Engagements::Legacy/}, '').to_i
            {
              allows_bounty_splitting: node.allows_bounty_splitting || false,
              average_time_to_bounty_awarded: node.most_recent_sla_snapshot&.average_time_to_bounty_awarded,
              average_time_to_first_program_response:
                node.most_recent_sla_snapshot&.average_time_to_first_program_response,
              average_time_to_report_resolved: node.most_recent_sla_snapshot&.average_time_to_report_resolved,
              handle: node.handle,
              id: id,
              managed_program: node.triage_active || false,
              name: node.name,
              offers_bounties: node.offers_bounties || false,
              offers_swag: node.offers_swag || false,
              response_efficiency_percentage: node.response_efficiency_percentage,
              submission_state: node.submission_state,
              url: node.url,
              website: node.website
            }
          end)
        end

        after = page.data.teams.page_info.end_cursor
        break unless page.data.teams.page_info.has_next_page
      end

      programs.sort_by do |program|
        program[:id]
      end
    end

    def program_targets(program)
      scopes = []
      after = nil

      Kernel.loop do
        page = nil
        page_scopes = nil
        retryable do
          page = @graphql_client.query(@program_query, variables: {handle: program[:handle], after: after})
          raise StandardError, page.errors.details.to_s unless page.errors.details.empty?

          page_scopes = page.data.team.structured_scopes.nodes
          raise StandardError, 'Some scopes timed out' if page_scopes.any?(&:nil?)

          after = page.data.team.structured_scopes.page_info.end_cursor
        end

        scopes.concat(page_scopes.map(&:to_h))

        break unless page.data.team.structured_scopes.page_info.has_next_page
      end

      raise StandardError, 'Got duplicate scopes' if scopes.length != scopes.uniq.length

      scopes = scopes.group_by do |scope|
        scope['eligible_for_submission']
      end.transform_values do |targets|
        targets.sort_by do |scope|
          [scope['asset_identifier'], scope['asset_type']]
        end
      end

      [scopes.fetch(true, []), scopes.fetch(false, [])]
    end

    def schema
      return @schema if instance_variable_defined?(:@schema)

      @http = ::GraphQL::Client::HTTP.new('https://hackerone.com/graphql') do
        def headers(_context) # rubocop:disable Lint/NestedMethodDefinition
          @headers ||= begin
            uri = URI('https://hackerone.com/directory/programs')
            response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
              http.request(Net::HTTP::Get.new(uri))
            end

            cookie = response['Set-Cookie']
            csrf_token = response.body.match(/name="csrf-token"\s+content="([^"]+)"/)[1]

            {
              cookie: cookie,
              'x-csrf-token': csrf_token
            }
          end
        end
      end
      @schema = ::GraphQL::Client.load_schema(@http)
      @graphql_client = ::GraphQL::Client.new(schema: @schema, execute: @http)
      @graphql_client.allow_dynamic_queries = true

      @directory_query = @graphql_client.parse <<~GRAPHQL
        query($after: String) {
          teams(first: 50, after: $after, secure_order_by: {started_accepting_at: {_direction: DESC}}, where: {
            _and:[
              {
                _or: [
                  {submission_state:{_eq:open}},
                  {submission_state:{_eq:api_only}},
                  {external_program:{}}
                ]},
                {_not:{external_program:{}}},
                {_or:[
                  {_and:[
                    {state:{_neq:sandboxed}},
                    {state:{_neq:soft_launched}}
                  ]},
                {external_program:{}}
              ]}
            ]
          }) {
            pageInfo {
              endCursor
              hasNextPage
            },
            nodes {
              allows_bounty_splitting,
              handle,
              id,
              most_recent_sla_snapshot {
                average_time_to_bounty_awarded,
                average_time_to_first_program_response,
                average_time_to_report_resolved
              }
              name,
              offers_bounties,
              offers_swag,
              response_efficiency_percentage,
              submission_state,
              triage_active,
              url,
              website
            }
          }
        }
      GRAPHQL

      @program_query = @graphql_client.parse <<~GRAPHQL
        query($handle: String!, $after: String) {
          team(handle: $handle) {
            structured_scopes(first: 100, after: $after, archived: false) {
              pageInfo {
                endCursor,
                hasNextPage
              },
              nodes {
                asset_identifier,
                asset_type,
                availability_requirement,
                confidentiality_requirement,
                eligible_for_bounty,
                eligible_for_submission,
                instruction,
                integrity_requirement,
                max_severity
              }
            }
          }
        }
      GRAPHQL

      @schema
    end

    def uris
      uris = scan.flat_map do |program|
        next [] if %w[paused disabled].include?(program[:submission_state])

        program['targets']['in_scope']
      end.select do |scope|
        %w[URL WILDCARD].include?(scope['asset_type'])
      end.map do |scope|
        scope['asset_identifier']
      end

      # Handle Oath's unusual usage of scopes
      # This returns some garbage data that gets filtered out later
      extra_uris = scan.select do |program|
        %w[verizonmedia spotify].include?(program[:handle])
      end.flat_map do |program|
        program['targets']['in_scope'].flat_map do |scope|
          next [] if scope[:instruction].nil?

          markdown = Kramdown::Document.new(scope['instruction']).to_html
          URI.extract(scope['instruction'] + "\n" + scope['instruction'].scan(/\(([^)]*)\)/).flatten.join(' ')) +
            Twingly::URL::Utilities.extract_valid_urls(markdown).map(&:to_s)
        end
      end

      uris + extra_uris
    end
  end
end
