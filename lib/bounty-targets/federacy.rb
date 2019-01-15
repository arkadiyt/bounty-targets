# frozen_string_literal: true

require 'json'
require 'net/https'
require 'uri'

module BountyTargets
  class Federacy
    def scan
      return @scan_results if instance_variable_defined?(:@scan_results)

      @scan_results = directory_index.map do |program|
        program.merge(program_scopes(program))
      end.sort_by do |program|
        program[:name]
      end
    end

    def uris
      scan.flat_map do |program|
        program[:targets][:in_scope]
      end.select do |scope|
        scope[:type] == 'website'
      end.map do |scope|
        scope[:target]
      end
    end

    private

    def directory_index
      programs = ::JSON.parse(::Net::HTTP.get(::URI.parse('https://one.federacy.com/api/programs')))
      programs.map do |program|
        {
          id: program['id'],
          name: program['program_name'],
          url: program['url']
        }
      end
    end

    def program_scopes(program)
      uri = ::URI.parse("https://one.federacy.com/api/program_scopes?program_id=#{program[:id]}")
      response = ::JSON.parse(::Net::HTTP.get(uri))
      scopes = response.group_by { |scope| scope['in_scope'] }
      {
        targets: {
          in_scope: scopes_to_hashes(scopes[true]),
          out_of_scope: scopes_to_hashes(scopes[false])
        }
      }
    end

    def scopes_to_hashes(scopes)
      Array(scopes).map do |scope|
        {
          type: scope['scope_type'],
          target: scope['identifier'],
          bounty: scope['bounty'],
          impact: scope['impact']
        }
      end
    end
  end
end
