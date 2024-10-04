# frozen_string_literal: true

require 'json'
require 'ssrf_filter'
require 'uri'

module BountyTargets
  class YesWeHack
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
        %w[api web-application].include?(scope[:type])
      end.map do |scope|
        scope[:target]
      end
    end

    private

    def directory_index
      uri = URI('https://api.yeswehack.com/programs')
      page = 1
      programs = []
      ::Kernel.loop do
        uri.query = ::URI.encode_www_form(page: page)
        result = ::JSON.parse(SsrfFilter.get(uri).body)
        page += 1
        programs.concat(result['items'].map do |program|
          {
            id: program['slug'],
            name: program['title'],
            public: program['public'],
            disabled: program['disabled'],
            managed: program['managed'],
            min_bounty: program['bounty_reward_min'],
            max_bounty: program['bounty_reward_max']
          }
        end)

        break unless result['items'].length == result['pagination']['results_per_page']
      end

      programs
    end

    def program_scopes(program)
      uri = ::URI.parse('https://api.yeswehack.com/programs/' + ::URI.encode_www_form_component(program[:id]))
      response = ::JSON.parse(SsrfFilter.get(uri).body)
      {
        targets: {
          in_scope: (response['scopes'] || []).map do |scope|
            {
              target: scope['scope'],
              type: scope['scope_type']
            }
          end,
          out_of_scope: (response['out_of_scope'] || []).map do |scope|
            {
              target: scope,
              type: 'other'
            }
          end
        }
      }
    end
  end
end
