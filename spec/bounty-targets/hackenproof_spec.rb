# frozen_string_literal: true

describe BountyTargets::Hackenproof do
  subject(:client) { described_class.new }

  before :all do
    described_class.make_all_methods_public!
  end

  it 'fetches a list of programs' do
    stub_request(:get, %r{/bug-bounty-programs-list\?page=1}).with(headers: {host: 'hackenproof.com'}).to_return(status:
      200, body: File.read('spec/fixtures/hackenproof/programs_1.json'))
    stub_request(:get, %r{/bug-bounty-programs-list\?page=2}).with(headers: {host: 'hackenproof.com'}).to_return(status:
      200, body: File.read('spec/fixtures/hackenproof/programs_2.json'))

    expect(client.directory_index).to eq(
      [
        {
          archived: true,
          id: '63517622fd18045e8d9b72bc',
          name: 'VirtuSwap DEX APP',
          slug: 'virtuswap-dex-app-1',
          triaged_by_hackenproof: true,
          url: 'https://hackenproof.com/programs/virtuswap-dex-app-1'
        }
      ]
    )
  end

  it 'fetches program scopes' do
    scopes = File.read('spec/fixtures/hackenproof/scopes.json')
    stub_request(:get, %r{/bug-bounty-programs-list/my-program}).with(headers: {host: 'hackenproof.com'})
      .to_return(status: 200, body: scopes)
    expect(client.program_scopes(slug: 'my-program')).to eq(
      {
        targets: {
          in_scope: [
            {
              instruction: 'Polygon POS - Heimdall',
              reward: 'Bounty',
              severity: 'Critical',
              type: 'Other',
              target: 'https://github.com/maticnetwork/heimdall/'
            }
          ],
          out_of_scope: []
        }
      }
    )
  end
end
