# frozen_string_literal: true

require 'net/https'
require 'nokogiri'
require 'uri'

module BountyTargets
  class Bountygraph
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
      end
    end

    private

    def directory_index
      document = ::Nokogiri::HTML(::Net::HTTP.get(::URI.parse('https://bountygraph.com/programs')))
      document.css('div.miniprogramdescription').map do |program|
        anchor = program.css('span.miniprogramname > a')
        {
          id: anchor.attr('href').value.gsub(%r{^/programs/}, ''),
          name: anchor.inner_text,
          description: program.css('p').inner_text
        }
      end
    end

    def program_scopes(program)
      uri = ::URI.parse("https://bountygraph.com/programs/#{program[:id]}")
      document = ::Nokogiri::HTML(::Net::HTTP.get(uri))

      # Bountygraph has extremely unstructured scopes unfortunately. This is best effort and won't
      # be good
      scopes = []
      current = document.css('h2:contains("Scope")').first
      ::Kernel.loop do
        break if current.nil? || (current.name == 'h2' && current.inner_text == 'Exclusions')

        scopes.concat(current.css('code').map(&:inner_text))
        current = current.next_sibling
      end

      {
        targets: {
          in_scope: scopes,
          out_of_scope: []
        }
      }
    end
    #
    # def scopes_to_hashes(scopes)
    #   Array(scopes).map do |scope|
    #     {
    #       type: scope['scope_type'],
    #       target: scope['identifier'],
    #       bounty: scope['bounty'],
    #       impact: scope['impact']
    #     }
    #   end
    # end
  end
end
