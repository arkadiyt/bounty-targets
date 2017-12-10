# frozen_string_literal: true

require 'active_support/core_ext/hash/slice'
require 'json'
require 'net/https'
require 'graphql/client'
require 'graphql/client/http'

module BountyTargets
  class Hackerone
    def scan
      return @scan_results if instance_variable_defined?(:@scan_results)
      schema # initialize graphql client

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
      # Hackerone has ~5000 programs with ~200 signed up directly and the rest being
      # community curated pages. The graphql fields that specify this information about a program
      # are declared `!` (non-null), but hackerone returns them as null for some teams, causing
      # graphql errors. Hackerone itself does not run into this error because they don't use the graphql
      # endpoint to fetch the team directory, they use a different REST endpoint. We
      # do the same here

      uri = URI('https://hackerone.com/programs/search')
      page = 1
      programs = []
      ::Kernel.loop do
        uri.query = ::URI.encode_www_form(query: 'type:hackerone', sort: 'published_at:ascending', page: page)
        result = ::JSON.parse(::Net::HTTP.get(uri))
        page += 1

        programs.concat(result['results'].map do |program|
          {
            id: program['id'],
            name: program['name'],
            handle: program['handle'],
            url: "https://hackerone.com#{program['url']}",
            offers_bounties: program['meta']['offers_bounties'],
            quick_to_bounty: program['meta']['quick_to_bounty'],
            quick_to_first_response: program['meta']['quick_to_first_response']
          }
        end)

        break if programs.size == result['total']
      end

      programs
    end

    def program_targets(program)
      scopes = []
      after = nil

      Kernel.loop do
        page = @graphql_client.query(@query, variables: {handle: program[:handle], after: after})
        after = page.data.team.structured_scopes.page_info.end_cursor
        page_scopes = page.data.team.structured_scopes.edges

        unless page.errors.details.empty?
          raise StandardError, page.errors.details.to_s
        end

        raise StandardError, 'Some scopes timed out' if page_scopes.any?(&:nil?)
        scopes.concat(page_scopes.map do |edge|
          edge.node.to_h
        end)

        break unless page.data.team.structured_scopes.page_info.has_next_page
      end

      raise StandardError, 'Got duplicate scopes' if scopes.length != scopes.uniq.length

      scopes = scopes.group_by do |scope|
        scope['eligible_for_submission']
      end.map do |key, targets|
        [key, targets.sort_by do |scope|
          scope['asset_identifier']
        end]
      end.to_h

      [scopes.fetch(true, []), scopes.fetch(false, [])]
    end

    def schema
      return @schema if instance_variable_defined?(:@schema)

      @http = ::GraphQL::Client::HTTP.new('https://hackerone.com/graphql')
      @schema = ::GraphQL::Client.load_schema(@http)
      @graphql_client = ::GraphQL::Client.new(schema: @schema, execute: @http)
      @graphql_client.allow_dynamic_queries = true

      @query = @graphql_client.parse <<~GRAPHQL
        query($handle: String!, $after: String) {
          team(handle: $handle) {
            structured_scopes(first: 100, after: $after) {
              pageInfo {
                endCursor,
                hasNextPage,
                hasPreviousPage,
                startCursor
              },
              total_count,
              edges {
                cursor,
                node {
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
        }
      GRAPHQL

      @schema
    end

    def uris
      scan.flat_map do |program|
        program['targets']['in_scope']
      end.select do |scope|
        scope['asset_type'] == 'URL'
      end.map do |scope|
        scope['asset_identifier']
      end
    end
  end
end
