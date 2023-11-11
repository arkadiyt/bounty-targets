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
    scopes = File.read('spec/fixtures/intigriti/scopes.html')
    stub_request(:get, %r{/programs/Uphold/upholdcom/detail})
      .with(headers: {host: 'app.intigriti.com'}).to_return(status: 200, body: scopes)
    expect(client.program_scopes(url: 'https://app.intigriti.com/programs/Uphold/upholdcom/detail')).to eq(
    targets: {
      in_scope: [
        {
          description: 'iOS application. This is currently installable on Jailbroken devices, ' \
                       'please read the out-of-scope findings.',
          endpoint: '1101145849',
          impact: 'Tier 1',
          type: 'ios'
        },
        {
          description: 'Production WebWallet Application. Do not test service degradation attacks ' \
                       'or horizontal privilege here.On the business app side, we allow you to create ' \
                       "apps in sandbox, but you shouldn't be able to create them in Production.",
          endpoint: 'api.uphold.com',
          impact: 'Tier 1',
          type: 'url'
        },
        {
          description: 'Android application. This is currently installable on Jailbroken devices, please ' \
                       'read the out-of-scope findings.',
          endpoint: 'com.uphold.wallet',
          impact: 'Tier 1',
          type: 'android'
        },
        {
          description: 'Production WebWallet Application. Do not test service degradation ' \
                       'attacks or horizontal privilege here.',
          endpoint: 'uphold.com/dashboard',
          impact: 'Tier 1',
          type: 'url'
        },
        {
          description: 'Use this environment for financial transaction testing, degradation attacks, ' \
                       'or horizontal privilege attacks. Fund with Crypto Testnet Faucet (e.g. ' \
                       'https://coinfaucet.eu/en/btc-testnet/ for Bitcoin).On the business app side, we ' \
                       "allow you to create apps in sandbox, but you shouldn't be able to create them in Production.",
          endpoint: 'api-sandbox.uphold.com',
          impact: 'Tier 2',
          type: 'url'
        },
        {
          description: 'Use this environment for financial transaction testing, degradation attacks, ' \
                       'or horizontal privilege attacks. Fund with Crypto Testnet Faucet (e.g. ' \
                       'https://coinfaucet.eu/en/btc-testnet/ for Bitcoin)',
          endpoint: 'sandbox.uphold.com/dashboard',
          impact: 'Tier 2',
          type: 'url'
        },
        {
          description: 'We are willing to give bonuses on anything you find and we agree is impactful, ' \
                       'in the rest of our domain. Please note that third party services are out of scope ' \
                       'unless the issue is caused due to a misconfiguration by Uphold',
          endpoint: '*.uphold.com',
          impact: 'Tier 3',
          type: 'url'
        }
      ],
      out_of_scope: []
    }
  )
  end
end
