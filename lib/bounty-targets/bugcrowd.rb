# frozen_string_literal: true

require 'nokogiri'
require 'ssrf_filter'

module BountyTargets
  class Bugcrowd
    def scan
      return @scan_results if instance_variable_defined?(:@scan_results)

      @scan_results = directory_index.sort.map do |program_link|
        parse_program(program_link)
      end
    end

    def uris
      scan.flat_map do |program|
        program[:targets][:in_scope]
      end.select do |scope|
        ['api testing', 'other', 'website testing'].include?(scope[:type])
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
      response = ::SsrfFilter.get(URI(program_link)).body
      document = ::Nokogiri::HTML(response)

      name = document.css('h1.bc-panel__title').inner_text.strip
      raise StandardError, 'Bugcrowd program came back blank' if name.empty?

      allows_disclosure = document.css('div.bc-panel__main').all? do |node|
        node.inner_text !~ /This program does not allow disclosure/
      end

      managed_by_bugcrowd = document.css('.bc-stat').any? do |node|
        node.inner_text =~ /Managed by Bugcrowd/
      end

      safe_harbor = document.css('.bc-stat').find do |node|
        node.inner_text =~ /safe harbor/i
      end
      safe_harbor_value = case safe_harbor.inner_text.strip
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

      {
        name: name,
        url: program_link,
        allows_disclosure: allows_disclosure,
        managed_by_bugcrowd: managed_by_bugcrowd,
        safe_harbor: safe_harbor_value,
        max_payout: max_payout_amount,
        targets: {
          in_scope: scopes_to_hashes(document.css('#user-guides__bounty-brief__in-scope + div > table')),
          out_of_scope: scopes_to_hashes(document.css('#user-guides__bounty-brief__out-of-scope + div > table'))
        }
      }
    end

    def scopes_to_hashes(nodes)
      nodes.css('tbody > tr').map do |node|
        target, type = node.css('td').map { |td| td.inner_text.strip }
        raise StandardError, 'Error parsing bugcrowd target' if target.nil? || target.empty?

        {
          type: (type || '').downcase,
          target: target
        }
      end.sort_by do |scope|
        scope[:target]
      end
    end
  end
end
