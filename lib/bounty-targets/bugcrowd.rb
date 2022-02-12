# frozen_string_literal: true

require 'nokogiri'
require 'ssrf_filter'

module BountyTargets
  class Bugcrowd
    include Retryable

    def scan
      return @scan_results if instance_variable_defined?(:@scan_results)

      @scan_results = directory_index.sort.map do |program_link|
        retryable do
          parse_program(program_link)
        end
      end
    end

    def uris
      scan.flat_map do |program|
        program[:targets][:in_scope]
      end.select do |scope|
        %w[api other website].include?(scope[:type])
      end.map do |scope|
        scope[:target]
      end
    end

    private

    PAGE_SIZE = 25

    def directory_index
      program_links = []

      offset = 0
      uri = URI('https://bugcrowd.com/programs.json')
      ::Kernel.loop do
        response = JSON.parse(SsrfFilter.get(uri).body)

        programs = response['programs'].map do |program|
          "https://bugcrowd.com#{program['program_url']}"
        end
        program_links.concat(programs)

        break if programs.length < PAGE_SIZE

        offset += PAGE_SIZE
        uri = URI("https://bugcrowd.com/programs.json?sort[]=promoted-desc&offset[]=#{offset}")
      end

      program_links.reject do |link|
        link.start_with?('https://bugcrowd.com/programs/teasers/')
      end
    end

    def parse_program(program_link)
      uri = URI(program_link)
      response = ::SsrfFilter.get(uri).body
      document = ::Nokogiri::HTML(response)

      name = document.css('h1.bc-panel__title').inner_text.strip
      raise StandardError, 'Bugcrowd program came back blank' if name.empty?

      allows_disclosure = document.css('div.bc-panel__main').all? do |node|
        node.inner_text !~ /This program does not allow disclosure/
      end

      safe_harbor = document.css('.bc-stat__title').find do |node|
        node.inner_text =~ /safe harbor/i
      end
      safe_harbor_value = case safe_harbor&.inner_text&.strip
      when 'Safe harbor'
        'full'
      when 'Partial safe harbor'
        'partial'
      else
        'none'
      end

      max_payout = document.css('.bc-program-card__reward')
      max_payout_amount = max_payout.inner_text.strip.match(/\A.* – \$([0-9,]+).*per vulnerability\Z/m)
      max_payout_amount = if max_payout_amount.nil?
        0
      else
        max_payout_amount[1].gsub(',', '').to_i
      end

      uri.path += '/target_groups'
      groups = ::JSON.parse(::SsrfFilter.get(uri).body)['groups']
      {
        name: name,
        url: program_link,
        allows_disclosure: allows_disclosure,
        managed_by_bugcrowd: true, # Bugcrowd seems to have removed the flag for this / all programs are managed
        safe_harbor: safe_harbor_value,
        max_payout: max_payout_amount,
        targets: {
          in_scope: scopes_to_hashes(uri, groups.select { |group| group['in_scope'] == true }),
          out_of_scope: scopes_to_hashes(uri, groups.select { |group| group['in_scope'] == false })
        }
      }
    end

    def scopes_to_hashes(uri, groups)
      groups.flat_map do |group|
        targets_uri = uri.clone
        targets_uri.path = group['targets_url']
        ::JSON.parse(::SsrfFilter.get(targets_uri).body)['targets'].map do |target|
          {
            type: (target['category'] || '').downcase,
            target: target['name']
          }
        end
      end.sort_by do |scope|
        scope[:target]
      end
    end
  end
end
