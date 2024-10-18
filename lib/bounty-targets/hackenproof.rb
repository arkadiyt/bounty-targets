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
      document = nil

      ::Kernel.loop do
        retryable do
          document = ::JSON.parse(::SsrfFilter.get("https://hackenproof.com/bug-bounty-programs-list?page=#{page}",
            headers: {'hp-partners-bypass' => ENV.fetch('HACKENPROOF', nil)}).body)
        end
        programs.concat(document['programs'].map do |program|
          {
            id: program['id'],
            name: program['title'].strip,
            slug: program['slug'],
            url: "https://hackenproof.com/programs/#{program['slug']}",
            archived: program['state'] == 'archived',
            triaged_by_hackenproof: program['managed_by_company_name'] == 'HackenProof'
          }
        end)

        break if document['next_page'].nil?

        page += 1
      end

      programs
    end

    def program_scopes(program)
      retryable do
        response = ::JSON.parse(::SsrfFilter.get("https://hackenproof.com/bug-bounty-programs-list/#{program[:slug]}",
          headers: {'hp-partners-bypass' => ENV.fetch('HACKENPROOF', nil)}).body)
        grouped = response['scopes'].group_by do |scope|
          scope['out_of_scope']
        end
        {
          targets: {
            in_scope: (grouped[false] || []).map do |scope|
              normalize_scope(scope)
            end,
            out_of_scope: (grouped[true] || []).map do |scope|
              normalize_scope(scope)
            end
          }
        }
      end
    end

    def normalize_scope(scope)
      {
        target: scope['target'],
        type: scope['title'],
        instruction: (scope['target_description'] || '').strip,
        severity: scope['criticality'],
        reward: scope['reward_type']
      }
    end
  end
end
