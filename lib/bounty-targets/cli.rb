# frozen_string_literal: true

require 'base64'
require 'bounty-targets'
require 'English'
require 'erb'
require 'fileutils'
require 'net/https' # temporary workaround
require 'tmpdir'
require 'uri'

module BountyTargets
  class CLI
    def run!
      timestamp = Time.now
      root = File.expand_path(File.join(__dir__, '..', '..'))

      FileUtils.rm_rf(Dir.glob('/tmp/*'))
      with_ssh_keys do |git_ssh_cmd|
        Dir.mktmpdir do |tmpdir|
          Dir.chdir(tmpdir) do
            # Clone + setup
            `GIT_SSH_COMMAND=#{git_ssh_cmd} git clone #{ENV.fetch('GIT_HOST')} --depth 1 .`
            `git config user.name 'bounty-targets'`
            `git config user.email '<>'`

            # Fetch all bug bounty data
            ::FileUtils.rm_rf('data')
            scan!(File.join(Dir.pwd, 'data'))

            break if `git status --porcelain`.empty?

            # Generate README file
            erb = ERB.new(File.read(File.join(root, 'config', 'README.md.erb')))
            readme = erb.result_with_hash(timestamp: timestamp.strftime('%A %m/%d/%Y %R (UTC)'))
            File.write('README.md', readme)

            # Commit + push
            commits = File.readlines(File.join(root, 'config', 'commits.txt'))
            commit_message = commits.sample(2).map(&:strip).map(&:capitalize).join(' ') +
              ' (' + timestamp.strftime('%m-%d-%Y %R') + ')'
            `git add .`
            `git commit -m '#{commit_message}'`
            `GIT_SSH_COMMAND=#{git_ssh_cmd} git push origin HEAD:main`
            raise StandardError, "Got exit code #{$CHILD_STATUS.exitstatus}" unless $CHILD_STATUS.success?
          end
        end
      end
    end

    def scan!(output_dir)
      FileUtils.mkdir_p(output_dir)

      clients = {
        bugcrowd: BountyTargets::Bugcrowd.new,
        federacy: BountyTargets::Federacy.new,
        # hackenproof: BountyTargets::Hackenproof.new,
        hackerone: BountyTargets::Hackerone.new,
        intigriti: BountyTargets::Intigriti.new,
        yeswehack: BountyTargets::YesWeHack.new
      }

      uris = clients.map do |name, client|
        Thread.new do
          File.write(File.join(output_dir, "#{name}_data.json"), ::JSON.pretty_generate(client.scan))
          # Sanity check for changes in page markup, network issues, etc
          uris = client.uris
          raise StandardError, "Missing uris for #{name}" if uris.all?(&:empty?)

          uris
        end
      end.flat_map(&:value)
      File.write(File.join(output_dir, 'hackerone_schema.graphql'), clients[:hackerone].schema.to_definition)

      domains, wildcards = parse_all_uris(uris)
      File.write(File.join(output_dir, 'domains.txt'), domains.join("\n"))
      File.write(File.join(output_dir, 'wildcards.txt'), wildcards.join("\n"))
    end

    private

    def parse_all_uris(uris)
      domains = []
      wildcards = []

      uris.each do |uri|
        uri.split(',').each do |target|
          next unless target.include?('.')

          uri = parse_uri(target)
          uri = parse_uri("http://#{target}") if uri&.host.nil?

          next unless valid_uri?(uri)

          arr = uri.host.include?('*') ? wildcards : domains
          arr << uri.host.downcase
        end
      end

      [domains.uniq, wildcards.uniq]
    end

    def parse_uri(str)
      URI(str)
    rescue URI::InvalidURIError
      nil
    end

    def valid_uri?(uri)
      return false unless uri&.host

      return false if uri.host.count('()').positive?

      # iOS/Android/FireOS mobile app links
      return false if %w[itunes.apple.com play.google.com www.amazon.com].include?(uri.host)

      # Executable files
      return false if uri.host.end_with?('.exe')

      # Links to source code (except exactly github.com/gitlab.com, which are scopes on hackerone)
      return false if %w[github.com gitlab.com].include?(uri.host) && !['', '/'].include?(uri.path)

      true
    end

    def with_ssh_keys(&)
      Dir.mktmpdir do |tmpdir|
        known_hosts_path = File.expand_path(File.join(__dir__, '..', '..', 'config', 'known_hosts'))

        privkey_path = File.join(tmpdir, 'id_rsa')
        File.write(privkey_path, Base64.strict_decode64(ENV.fetch('SSH_PRIV_KEY')), perm: 0o700)
        File.write(File.join(tmpdir, 'id_rsa.pub'), ENV.fetch('SSH_PUB_KEY'))

        git_ssh = "\"ssh -i '#{privkey_path}' -o UserKnownHostsFile='#{known_hosts_path}' -o HashKnownHosts='no'\""

        yield git_ssh
      end
    end
  end
end
