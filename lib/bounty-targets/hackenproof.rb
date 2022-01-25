# frozen_string_literal: true

require 'nokogiri'
require 'ssrf_filter'
require 'uri'

module BountyTargets
  class Hackenproof
    include Retryable

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
        scope[:type] == 'Web'
      end.map do |scope|
        scope[:target]
      end
    end

    private

    def directory_index
      page = 1
      programs = []

      ::Kernel.loop do
        document = ::Nokogiri::HTML(::SsrfFilter.get("https://hackenproof.com/programs?page=#{page}").body)

        programs.concat(document.css('div.bounty-programs-list--items').map do |node|
          link = node.css('h2 a').first
          {
            id: link.attributes['href'].value,
            name: link.inner_text.strip,
            url: URI.join('https://hackenproof.com', link.attributes['href'].value).to_s,
            archived: node.classes.include?('archived-program')
          }
        end)

        break if document.css('.last').empty?

        page += 1
      end

      programs
    end

    def program_scopes(program)
      document = ::Nokogiri::HTML(::SsrfFilter.get(program[:url]).body)
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
