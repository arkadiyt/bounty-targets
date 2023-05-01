# frozen_string_literal: true

describe BountyTargets::Intigriti do
  subject(:client) { described_class.new }

  before :all do
    described_class.make_all_methods_public!
  end

  it 'fetches a list of programs' do
    programs = File.read('spec/fixtures/intigriti/programs.json')
    stub_request(:get, %r{/core/public/program}).with(headers: {host: 'api.intigriti.com'})
      .to_return(status: 200, body: programs)
    expect(client.directory_index).to eq(
      [
        {
          id: '0d0034de-b53e-47b8-9a9d-41c302c49b5a',
          name: 'Torfs',
          company_handle: 'torfs',
          handle: 'torfs',
          confidentiality_level: 'public',
          url: 'https://www.intigriti.com/programs/torfs/torfs/detail',
          status: 'open',
          min_bounty: 0,
          max_bounty: 5000
        },
        {
          id: '0d6d1230-beb5-489c-b306-cf9c2e06730f',
          name: 'De Volkskrant',
          company_handle: 'depersgroep',
          handle: 'devolkskrant',
          confidentiality_level: 'public',
          url: 'https://www.intigriti.com/programs/depersgroep/devolkskrant/detail',
          status: 'suspended',
          min_bounty: 0,
          max_bounty: 2000
        }
      ]
    )
  end

  it 'fetches program scopes' do
    scopes = File.read('spec/fixtures/intigriti/scopes.json')
    stub_request(:get, %r{/core/public/programs/vasco/vascomobileproducts})
      .with(headers: {host: 'api.intigriti.com'}).to_return(status: 200, body: scopes)
    expect(client.program_scopes(company_handle: 'vasco', handle: 'vascomobileproducts')).to eq(
      targets: {
        in_scope: [
          {
            description: 'DIGIPASS for Mobile app',
            endpoint: '559799930',
            type: 'ios'
          },
          {
            description: 'DIGIPASS for Mobile app',
            endpoint: 'com.DIGIPASS_DEMO_ANDROID',
            type: 'android'
          },
          {
            description: 'The DIGIPASS App',
            endpoint: 'com.vasco.digipass.es',
            type: 'android'
          },
          {
            description: 'The DIGIPASS App',
            endpoint: 'the-digipass-app/id1172835583',
            type: 'ios'
          }
        ],
        out_of_scope: []
      }
    )
  end
end
