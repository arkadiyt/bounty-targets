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
      schema # initialize graphcl client

      @scan_results = []

      after = nil
      Kernel.loop do
        page = @graphql_client.query(@query, variables: {after: after})
        after = page.data.teams.page_info.end_cursor
        nodes = page.data.teams.edges.map(&:node)

        if nodes.reject(&:nil?).length != nodes.length
          raise StandardError, 'Some teams timed out'
        end

        @scan_results.concat(nodes.map(&method(:convert_to_hash)))

        break unless page.data.teams.page_info.has_next_page
      end

      @scan_results
    end

    def schema
      return @schema if instance_variable_defined?(:@schema)

      @http = GraphQL::Client::HTTP.new('https://hackerone.com/graphql')
      @schema = GraphQL::Client.load_schema(@http)
      @graphql_client = GraphQL::Client.new(schema: @schema, execute: @http)
      @graphql_client.allow_dynamic_queries = true

      # Trying to paginate more than 20 teams at a time causes results to be silently dropped
      @query = @graphql_client.parse <<~GRAPHQL
        query($after: String) {
          teams(first: 20, after: $after) {
            pageInfo {
              #{fields_for_type('PageInfo')},
            },
            total_count,
            edges {
              node {
                #{fields_for_type('Team', %w[structured_scopes submission_state])},
                structured_scopes(first: 100) {
                  total_count,
                  edges {
                    node {
                      #{fields_for_type('StructuredScope', %w[created_at])}
                    }
                  }
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

    private

    def convert_to_hash(node)
      node = node.to_h

      result = node.slice(*%w[name url offers_bounties offers_swag])
      result['targets'] = {
        'in_scope' => [],
        'out_of_scope' => [],
      }

      Array(node.dig('structured_scopes', 'edges')).each do |scope|
        scope = scope['node']
        key = scope['eligible_for_submission'] == true ? 'in_scope' : 'out_of_scope'
        scope = scope.slice(*%w[asset_identifier asset_type availability_requirement confidentiality_requirement
          eligible_for_bounty eligible_for_submission instruction integrity_requirement max_severity])
        result['targets'][key] << scope
      end

      result
    end

    def fields_for_type(type, exclude = [])
      @schema.get_fields(@schema.types[type]).select do |key, field|
        field.arguments.empty? && !exclude.include?(key)
      end.keys.join(',')
    end
  end
end
