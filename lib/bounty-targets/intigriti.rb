# frozen_string_literal: true

require 'json'
require 'ssrf_filter'
require 'uri'
require 'nokogiri'

module BountyTargets
  class Intigriti
    STATUSES = %w[_ wizard draft open suspended closing closed archived].freeze
    CONFIDENTIALITY_LEVELS = %w[_ inviteonly application registered public].freeze
    TYPES = %w[_ url android ios iprange device other wildcard].freeze
    TIERS = [
      '',
      'No Bounty',
      'Tier 3',
      'Tier 2',
      'Tier 1',
      'Out of scope'
    ].freeze

    def scan
      return @scan_results if instance_variable_defined?(:@scan_results)

      @scan_results = directory_index.select do |program|
        program[:confidentiality_level] == 'public' && program[:status] == 'open' && program[:tacRequired] != true &&
          program[:twoFactorRequired] != true
      end.map do |program|
        program.merge(program_scopes(program))
      end.sort_by do |program|
        program[:name]
      end
    end

    def uris
      scan.flat_map do |program|
        program[:targets][:in_scope]
      end.select do |scope|
        %w[url wildcard].include?(scope[:type])
      end.map do |scope|
        scope[:endpoint]
      end
    end

    private

    def encode(component)
      # Ruby dropped URI.encode, and CGI.escape converts spaces to `+` instead of `%20`
      URI.encode_www_form_component(component).gsub('+', '%20')
    end

    def directory_index
      page = ::Nokogiri::HTML(SsrfFilter.get(::URI.parse('https://www.intigriti.com/programs')).body)
      script = page.css('script').max_by do |node|
        node.to_s.length
      end.inner_text.match(/self\.__next_f\.push\(\[1,(.*)\]/)[1]
      programs = JSON.parse(JSON.parse(script)[2..])[3]['children'][1][3]['programs']
      programs.map do |program|
        {
          id: program['programId'],
          name: program['name'],
          company_handle: program['companyHandle'],
          handle: program['handle'],
          url: 'https://www.intigriti.com/programs/' + encode(program['companyHandle']) + '/' +
            encode(program['handle']) + '/detail',
          status: STATUSES[program['status']],
          confidentiality_level: CONFIDENTIALITY_LEVELS[program['confidentialityLevel']],
          tacRequired: program['tacRequired'],
          twoFactorRequired: program['twoFactorRequired'],
          min_bounty: program['minBounty'],
          max_bounty: program['maxBounty']
        }
      end
    end

    def program_scopes(program)
      url = "https://app.intigriti.com/api/core/public/programs/#{encode(program[:company_handle])}/#{encode(program[:handle])}"
      targets = (JSON.parse(SsrfFilter.get(url).body)['domains'].max_by do |domains|
        domains['createdAt']
      end)['content'].map do |content|
        {
          type: TYPES[content['type']],
          endpoint: content['endpoint'],
          description: content['description'],
          impact: TIERS[content['bountyTierId']]
        }
      end.group_by do |scope|
        scope[:impact] != 'Out of scope'
      end

      {
        targets: {
          in_scope: targets[true] || [],
          out_of_scope: targets[false] || []
        }
      }
    end
  end
end
