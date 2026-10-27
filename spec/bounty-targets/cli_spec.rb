# frozen_string_literal: true

require 'bounty-targets/cli'

RSpec.describe BountyTargets::CLI do
  describe '#run!' do
    it 'does not clear arbitrary system temporary files' do
      cli = described_class.new

      allow(cli).to receive(:with_ssh_keys).and_yield('ssh-command')
      allow(Dir).to receive(:mktmpdir).and_yield('/tmp/bounty-targets')
      allow(Dir).to receive(:chdir).and_yield
      allow(FileUtils).to receive(:rm_rf)
      allow(cli).to receive(:scan!)
      allow(cli).to receive(:"`").and_return('')

      expect(Dir).not_to receive(:glob).with('/tmp/*')

      cli.run!
    end
  end
end
