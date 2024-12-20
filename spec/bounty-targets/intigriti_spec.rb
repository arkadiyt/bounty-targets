# frozen_string_literal: true

describe BountyTargets::Intigriti do
  subject(:client) { described_class.new }

  before :all do
    described_class.make_all_methods_public!
  end

  it 'fetches a list of programs' do
    programs = File.read('spec/fixtures/intigriti/programs.html')
    stub_request(:get, %r{/programs}).with(headers: {host: 'www.intigriti.com'})
      .to_return(status: 200, body: programs)
    expect(client.directory_index).to eq(
      [
        {
          company_handle: 'arbonia',
          confidentiality_level: 'public',
          handle: 'arboniavdpprogram',
          id: 'f2a437ca-68cb-455c-81ba-3b8cd1b21cb2',
          max_bounty: {'currency' => 'EUR', 'value' => 0},
          min_bounty: {'currency' => 'EUR', 'value' => 0},
          name: 'Arbonia VDP program',
          status: 'suspended',
          tacRequired: false,
          twoFactorRequired: false,
          url: 'https://www.intigriti.com/programs/arbonia/arboniavdpprogram/detail'
        },
        {
          company_handle: 'intigriti',
          confidentiality_level: 'public',
          handle: 'fastlane',
          id: 'e56d6838-a1da-46d4-9d89-8154e017ae89',
          max_bounty: {'currency' => 'EUR', 'value' => 0},
          min_bounty: {'currency' => 'EUR', 'value' => 0},
          name: 'Submit your research - Fast lane',
          status: 'suspended',
          tacRequired: false,
          twoFactorRequired: true,
          url: 'https://www.intigriti.com/programs/intigriti/fastlane/detail'
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
          endpoint: 'endpoint',
          impact: 'Tier 1',
          type: 'other'
        }
      ],
      out_of_scope: []
    }
  )
  end
end
