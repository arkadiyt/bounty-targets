# frozen_string_literal: true

describe BountyTargets::Intigriti do
  subject(:client) { described_class.new }

  before :all do
    described_class.make_all_methods_public!
  end

  it 'fetches a list of programs' do
    programs = File.read('spec/fixtures/intigriti/programs.json')
    tag = '123'
    stub_request(:get, %r{/programs}).with(headers: {host: 'www.intigriti.com'})
      .to_return(status: 200, body: "/_next/static/#{tag}/_buildManifest.js")
    stub_request(:get, %r{/_next/data/#{tag}/en/programs.json}).with(headers: {host: 'www.intigriti.com'})
      .to_return(status: 200, body: programs)
    expect(client.directory_index).to eq(
      [
        {
          company_handle: 'doccle',
          confidentiality_level: 'application',
          handle: 'doccle',
          id: '12715f4b-d10e-415f-a309-6ab042f6158a',
          status: 'open',
          tacRequired: true,
          url: 'https://www.intigriti.com/programs/doccle/doccle/detail',
          max_bounty: {'currency' => 'EUR', 'value' => 2500},
          min_bounty: {'currency' => 'EUR', 'value' => 0},
          name: 'Doccle'
        },
        {
          company_handle: 'bpost',
          confidentiality_level: 'application',
          handle: 'e-tracker',
          id: 'a09e497e-fd75-4b56-afa0-7a6689389b76',
          tacRequired: false,
          max_bounty: {'currency' => 'EUR', 'value' => 0},
          min_bounty: {'currency' => 'EUR', 'value' => 0},
          name: 'e-tracker',
          status: 'open',
          url: 'https://www.intigriti.com/programs/bpost/e-tracker/detail'
        }
      ]
    )
  end

  it 'fetches program scopes' do
    scopes = File.read('spec/fixtures/intigriti/scopes.json')
    stub_request(:get, %r{/api/core/public/programs/intel/intel})
      .with(headers: {host: 'app.intigriti.com'}).to_return(status: 200, body: scopes)
    expect(client.program_scopes(company_handle: 'intel', handle: 'intel')).to eq(
    targets: {
      in_scope: [
        {
          description: nil,
          endpoint: "(Hardware)\tProcessor (inclusive of micro-code ROM + updates)",
          impact: 'Tier 1',
          type: 'other'
        }
      ],
      out_of_scope: []
    }
  )
  end
end
