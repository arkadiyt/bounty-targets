# frozen_string_literal: true

require 'base64'
require 'json'
require 'kramdown'
require 'twingly/url/utilities'

module BountyTargets
  class Hackerone
    include Retryable

    def initialize
      graphql_init
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
          page = graphql_query(@directory_query, after: after)
          error = page.dig('errors', 'details')
          raise StandardError, error unless error.nil?

          programs.concat(page.dig('data', 'teams', 'nodes').map do |node|
            id = Base64.decode64(node['id']).gsub(%r{^gid://hackerone/Engagements::Legacy/}, '').to_i
            {
              allows_bounty_splitting: node['allows_bounty_splitting'] || false,
              average_time_to_bounty_awarded: node.dig('most_recent_sla_snapshot', 'average_time_to_bounty_awarded'),
              average_time_to_first_program_response:
                node.dig('most_recent_sla_snapshot', 'average_time_to_first_program_response'),
              average_time_to_report_resolved: node.dig('most_recent_sla_snapshot', 'average_time_to_report_resolved'),
              handle: node['handle'],
              id: id,
              managed_program: node['triage_active'] || false,
              name: node['name'],
              offers_bounties: node['offers_bounties'] || false,
              offers_swag: node['offers_swag'] || false,
              response_efficiency_percentage: node['response_efficiency_percentage'],
              submission_state: node['submission_state'],
              url: node['url'],
              website: node['website']
            }
          end)
        end

        after = page.dig('data', 'teams', 'pageInfo', 'endCursor')
        break unless page.dig('data', 'teams', 'pageInfo', 'hasNextPage')
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
          page = graphql_query(@program_query, handle: program[:handle], after: after)
          error = page.dig('errors', 'details')
          raise StandardError, error unless error.nil?

          page_scopes = page.dig('data', 'team', 'structured_scopes', 'nodes')
          raise StandardError, 'Some scopes timed out' if page_scopes.any?(&:empty?)

          after = page.dig('data', 'team', 'structured_scopes', 'pageInfo', 'endCursor')
        end

        scopes.concat(page_scopes)

        break unless page.dig('data', 'team', 'structured_scopes', 'pageInfo', 'hasNextPage')
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

    def graphql_init
      uri = URI('https://hackerone.com/directory/programs')
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
        http.request(Net::HTTP::Get.new(uri))
      end

      @cookie = response['Set-Cookie']
      @csrf_token = response.body.match(/name="csrf-token"\s+content="([^"]+)"/)[1]

      @directory_query = <<~GRAPHQL
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

      @program_query = <<~GRAPHQL
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
    end

    def graphql_query(query, variables)
      uri = URI('https://hackerone.com/graphql')
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
        request = Net::HTTP::Post.new(uri)
        request.content_type = 'application/json'
        request['Cookie'] = @cookie
        request['X-Csrf-Token'] = @csrf_token
        request.body = JSON.generate({
          query: query,
          variables: variables
        })
        http.request(request)
      end
      JSON.parse(response.body)
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
