# frozen_string_literal: true

require 'nokogiri'
require 'net/https'

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
        response = ::Net::HTTP.get(uri)
        document = ::Nokogiri::HTML(response)
        program_links.concat(document.css('li.bounty h4 a').map do |node|
          "https://bugcrowd.com#{node.attributes['href'].value}"
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

      {
        name: document.css('div.bounty-header-text h1').inner_text.strip,
        url: program_link,
        targets: {
          in_scope: scopes_to_hashes(document.css('h3 + ul li.bc-target')),
          out_of_scope: scopes_to_hashes(document.css('h4 + ul li.bc-target'))
        }
      }
    end

    def scopes_to_hashes(nodes)
      nodes.map do |node|
        {
          type: node.css('p').inner_text.strip,
          target: node.css('code strong').inner_text.strip
        }
      end.sort_by do |scope|
        scope[:target]
      end
    end
  end
end
