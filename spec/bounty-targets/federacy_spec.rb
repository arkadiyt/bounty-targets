# frozen_string_literal: true

describe BountyTargets::Federacy do
  subject(:client) { described_class.new }

  before :all do
    described_class.make_all_methods_public!
  end

  it 'fetches a list of programs' do
    programs = File.read('spec/fixtures/federacy/programs.json')
    stub_request(:get, %r{/api/public_programs}).with(headers: {host: 'www.federacy.com'})
      .to_return(status: 200, body: programs)
    expect(client.directory_index).to eq(
      [
        {
          id: '955a3f33-3ca7-42b1-acf5-84da28d4c08c',
          name: 'Federacy',
          offers_awards: true,
          url: 'https://www.federacy.com/federacy'
        },
        {
          id: '50cea250-a08a-4581-93a5-5d973a261f45',
          name: 'CoinTracker',
          offers_awards: false,
          url: 'https://www.federacy.com/cointracker'
        }
      ]
    )
  end

  it 'fetches program scopes' do
    scopes = File.read('spec/fixtures/federacy/scopes.json')
    stub_request(:get, %r{/api/public_programs/50cea250-a08a-4581-93a5-5d973a261f45/program_scopes})
      .with(headers: {host: 'www.federacy.com'})
      .to_return(status: 200, body: scopes)
    expect(client.program_scopes(id: '50cea250-a08a-4581-93a5-5d973a261f45')).to eq(
      targets: {
        in_scope: [
          {
            type: 'website',
            target: 'www.cointracker.io'
          },
          {
            type: 'mobile app',
            target: 'https://itunes.apple.com/us/app/cointracker-crypto-portfolio/id1401499763?mt=8'
          },
          {
            type: 'mobile app',
            target: 'https://play.google.com/store/apps/details?id=io.cointracker.android'
          }
        ],
        out_of_scope: []
      }
    )
  end
end
