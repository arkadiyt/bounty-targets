# frozen_string_literal: true

require 'json'
require 'ssrf_filter'
require 'uri'

module BountyTargets
  class Intigriti
    STATUSES = %w[_ wizard draft open suspended closing closed archived].freeze
    CONFIDENTIALITY_LEVELS = %w[_ inviteonly application registered public].freeze
    TYPES = %w[_ url android ios iprange device other].freeze

    def scan
      return @scan_results if instance_variable_defined?(:@scan_results)

      @scan_results = directory_index.select do |program|
        program[:confidentiality_level] == 'public' && program[:status] == 'open'
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
        scope[:type] == 'url'
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
      page = SsrfFilter.get(::URI.parse('https://www.intigriti.com/programs')).body
      tag = page.match(%r{/_next/static/([^/]+)/_buildManifest.js})[1]
      programs = ::JSON.parse(SsrfFilter.get(::URI.parse("https://www.intigriti.com/_next/data/#{tag}/en/programs.json")).body)
      programs['pageProps']['programs'].map do |program|
        {
          id: program['programId'],
          name: program['name'],
          company_handle: program['companyHandle'],
          handle: program['handle'],
          url: 'https://www.intigriti.com/programs/' + encode(program['companyHandle']) + '/' +
            encode(program['handle']) + '/detail',
          status: STATUSES[program['status']],
          confidentiality_level: CONFIDENTIALITY_LEVELS[program['confidentialityLevel']],
          min_bounty: program['minBounty'],
          max_bounty: program['maxBounty']
        }
      end
    end

    def program_scopes(program)
      document = ::Nokogiri::HTML(SsrfFilter.get(program[:url]).body)
      in_scope = document.css('div.domain-container').map do |div|
        {
          type: div.css('.domainType').inner_text.strip.downcase,
          endpoint: div.css('.reference').inner_text.strip,
          description: div.css('.domain-description p').inner_text.strip,
          impact: div.css('.impact').inner_text.strip
        }
      end

      {
        targets: {
          in_scope: in_scope,
          out_of_scope: []
        }
      }
    end
  end
end
