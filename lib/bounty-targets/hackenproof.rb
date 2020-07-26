# frozen_string_literal: true

require 'nokogiri'
require 'ssrf_filter'
require 'uri'

module BountyTargets
  class Hackenproof
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
        scope[:type] == 'WEB'
      end.map do |scope|
        scope[:target]
      end
    end

    private

    def retryable(tries = 5)
      yield
    rescue StandardError
      tries -= 1
      tries <= 0 ? raise : sleep(2) && retry
    end

    def http_get(url)
      uri = ::URI.parse(url)
      retryable do
        # Can't use ssrf_filter here due to webmock bug handling ipv6 addresses
        response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https') do |http|
          http.get(uri)
        end
        raise StandardError, "Got #{response.code} response from Hackenproof" if response.code != '200'

        response.body
      end
    end

    def directory_index
      document = ::Nokogiri::HTML(http_get('https://hackenproof.com/programs'))

      document.css('div.bounty-programs-list--item').map do |node|
        link = node.css('h2 a').first
        {
          id: link.attributes['href'].value,
          name: link.inner_text.strip,
          url: URI.join('https://hackenproof.com', link.attributes['href'].value).to_s,
          archived: node.classes.include?('archived-program')
        }
      end
    end

    def program_scopes(program)
      document = ::Nokogiri::HTML(http_get(program[:url]))
      h4s = document.css('div#in_scope h4')
      {
        targets: {
          in_scope: scopes_to_hashes(h4s[0]),
          out_of_scope: scopes_to_hashes(h4s[1])
        }
      }
    end

    def scopes_to_hashes(tag)
      return [] unless tag

      table = ::Kernel.loop do
        tag = tag.next
        break tag if tag.name == 'table'
      end

      table.css('tbody > tr').map do |row|
        scopes_target = row.css('.scopes-target-inner')
        {
          target: scopes_target.css('h5').remove.inner_text.strip,
          type: row.css('td')[1].inner_text.strip,
          instruction: scopes_target.inner_text.strip,
          severity: row.css('td')[2].inner_text.strip,
          reward: row.css('td')[3].inner_text.strip
        }
      end
    end
  end
end
