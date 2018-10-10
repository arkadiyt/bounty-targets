# frozen_string_literal: true

require 'nokogiri'
require 'net/https'
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
        ['', 'api', 'other', 'website'].include?(scope[:type])
      end.map do |scope|
        scope[:target]
      end
    end

    private

    def directory_index
      program_links = []

      uri = URI('https://bugcrowd.com/programs')
      ::Kernel.loop do
        response = SsrfFilter.get(uri).body
        document = ::Nokogiri::HTML(response)
        program_links.concat(document.css('h4.bc-panel__title a').map do |node|
          uri = URI(node.attributes['href'].value)
          uri.absolute? ? uri.to_s : "https://bugcrowd.com#{uri}"
        end.reject do |link|
          # This is displayed as a "program" on the Bugcrowd directory, but it's
          # a recruitment ad, not a program
          link == 'https://www.bugcrowd.com/resource/help-wanted'
        end)

        next_page = document.css('li.bc-pagination__item--next a').first
        break unless next_page

        uri = URI("https://bugcrowd.com#{next_page.attributes['href'].value}")
      end

      program_links
    end

    def parse_program(program_link)
      response = ::Net::HTTP.get(URI(program_link))
      document = ::Nokogiri::HTML(response)

      name = document.css('h1.bc-panel__title').inner_text.strip
      raise StandardError, 'Bugcrowd program came back blank' if name.empty?

      allows_disclosure = document.css('div.bc-panel__main').all? do |node|
        node.inner_text !~ /This program does not allow disclosure/
      end

      {
        name: name,
        url: program_link,
        allows_disclosure: allows_disclosure,
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
