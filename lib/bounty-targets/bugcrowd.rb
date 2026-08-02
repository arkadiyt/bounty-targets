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
      end.compact
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

    def directory_index
      program_links = []

      page = 1
      ::Kernel.loop do
        uri = URI("https://bugcrowd.com/engagements.json?category=bug_bounty&sort_by=promoted&sort_direction=desc&page=#{page}")
        response = JSON.parse(SsrfFilter.get(uri).body)

        programs = response['engagements'].map do |program|
          "https://bugcrowd.com#{program['briefUrl']}"
        end
        break if programs.empty?

        program_links.concat(programs)
        page += 1
      end

      program_links
    end

    def parse_program(program_link)
      uri = URI(program_link)
      response = ::SsrfFilter.get(uri)
      return if response.code == '403'

      document = ::Nokogiri::HTML(response.body)

      brief_url = ::JSON.parse(document.css('div[data-react-class="ResearcherEngagementBrief"]')
        .attr('data-api-endpoints').value)['engagementBriefApi']['getBriefVersionDocument']
      brief = ::JSON.parse(::SsrfFilter.get(URI("https://#{uri.host}/#{brief_url}.json")).body)
      data = brief['data']['brief']
      brief_scope = brief['data']['scope']
      {
        name: data['name'],
        url: program_link,
        allows_disclosure: !brief['coordinatedDisclosure'],
        managed_by_bugcrowd: true, # Bugcrowd seems to have removed the flag for this / all programs are managed
        safe_harbor: data.dig('safeHarborStatus', 'status'),
        max_payout: brief_scope.select do |scope|
          scope['inScope'] == true
        end.map do |scope|
          scope.dig('rewardRangeData', '1', 'max')
        end.compact.max,
        targets: {
          in_scope: scopes_to_hashes_engagement(brief_scope.select do |scope|
            scope['inScope'] == true
          end.flatten),
          out_of_scope: scopes_to_hashes_engagement(brief_scope.select do |scope|
            scope['inScope'] == false
          end.flatten)
        }
      }
    end

    def scopes_to_hashes(uri, groups)
      groups.flat_map do |group|
        targets_uri = uri.clone
        targets_uri.path = group['targets_url']
        ::JSON.parse(::SsrfFilter.get(targets_uri).body)['targets'].flat_map do |target|
          # Some programs put the uri into target['name'] and some put it into target['uri']
          # No matter which way you parse it (or try to find the url with heuristics), people complain
          # so just include both of them
          result = []
          unless target['name'].nil? || target['name'] == ''
            result << {
              type: (target['category'] || '').downcase,
              target: target['name']
            }
          end
          unless target['uri'].nil? || target['uri'] == ''
            result << {
              type: (target['category'] || '').downcase,
              target: target['uri']
            }
          end
          result.uniq
        end
      end.sort_by do |scope|
        scope[:target]
      end
    end

    def scopes_to_hashes_engagement(scopes)
      scopes.flat_map do |targets|
        targets['targets'].map do |scope|
          {
            type: scope['category'],
            target: [scope['uri'], scope['name'], scope['ipAddress']].find do |target|
              !target.nil? && !target.empty?
            end,
            uri: scope['uri'],
            name: scope['name'],
            ipAddress: scope['ipAddress']
          }
        end
      end
    end
  end
end
