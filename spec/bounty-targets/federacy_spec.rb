# frozen_string_literal: true

require 'bounty-targets/federacy'

describe BountyTargets::Federacy do
  before :all do
    BountyTargets::Federacy.make_all_methods_public!
  end

  let(:subject) { BountyTargets::Federacy.new }

  it 'should fetch a list of programs' do
    programs = IO.read('spec/fixtures/federacy/programs.json')
    stub_request(:get, 'https://api.federacy.com/api/programs').to_return(status: 200, body: programs)
    expect(subject.directory_index).to eq([
      {
        id: '955a3f33-3ca7-42b1-acf5-84da28d4c08c',
        name: 'Federacy',
        url: 'https://api.federacy.com/api/programs/federacy'
      },
      {
        id: 'f24e4ca8-2cd1-49ee-9467-77af68ae9cec',
        name: 'Stacker',
        url: 'https://api.federacy.com/api/programs/stacker'
      },
      {
        id: '50cea250-a08a-4581-93a5-5d973a261f45',
        name: 'CoinTracker',
        url: 'https://api.federacy.com/api/programs/cointracker'
      },
      {
        id: '3ec4fbb9-d2df-4cc9-9cd6-7a1022b633d0',
        name: 'Webflow',
        url: 'https://api.federacy.com/api/programs/webflow'
      }
    ])
  end

  it 'should fetch program scopes' do
    scopes = IO.read('spec/fixtures/federacy/scopes.json')
    uri = 'https://api.federacy.com/api/program_scopes?program_id=50cea250-a08a-4581-93a5-5d973a261f45'
    stub_request(:get, uri).to_return(status: 200, body: scopes)
    expect(subject.program_scopes(id: '50cea250-a08a-4581-93a5-5d973a261f45')).to eq(
      targets: {
        in_scope: [
          {
            type: 'website',
            target: 'www.cointracker.io',
            bounty: 'money',
            impact: 'high'
          },
          {
            type: 'mobile app',
            target: 'https://itunes.apple.com/us/app/cointracker-crypto-portfolio/id1401499763?mt=8',
            bounty: 'money',
            impact: 'high'
          },
          {
            type: 'mobile app',
            target: 'https://play.google.com/store/apps/details?id=io.cointracker.android',
            bounty: 'money',
            impact: 'high'
          }
        ],
        out_of_scope: []
      }
    )
  end

  # TODO
  # it 'should merge results correctly' do
  # end
  #
  # it 'should filter uris' do
  # end
end
