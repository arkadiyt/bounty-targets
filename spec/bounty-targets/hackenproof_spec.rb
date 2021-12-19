# frozen_string_literal: true

describe BountyTargets::Hackenproof do
  before :all do
    BountyTargets::Hackenproof.make_all_methods_public!
  end

  let(:subject) { BountyTargets::Hackenproof.new }

  it 'should fetch a list of programs' do
    stub_request(:get, %r{/programs\?page=1}).with(headers: {host: 'hackenproof.com'}).to_return(status: 200,
      body: File.read('spec/fixtures/hackenproof/programs_1.html'))
    stub_request(:get, %r{/programs\?page=2}).with(headers: {host: 'hackenproof.com'}).to_return(status: 200,
      body: File.read('spec/fixtures/hackenproof/programs_2.html'))

    expect(subject.directory_index).to eq(
      [
        {
          id: '/allbridge/allbridge',
          name: 'Allbridge',
          url: 'https://hackenproof.com/allbridge/allbridge',
          archived: false
        },
        {
          id: '/avalanche/avalanche-general',
          name: 'Avalanche General',
          url: 'https://hackenproof.com/avalanche/avalanche-general',
          archived: false
        },
        {
          id: '/avalanche/avalanche-protocol',
          name: 'Avalanche Protocol',
          url: 'https://hackenproof.com/avalanche/avalanche-protocol',
          archived: false
        },
        {
          id: '/btse/btse-bug-bounty-program',
          name: 'BTSE Bug Bounty Program',
          url: 'https://hackenproof.com/btse/btse-bug-bounty-program',
          archived: false
        },
        {
          id: '/bitkub/bitkub',
          name: 'Bitkub',
          url: 'https://hackenproof.com/bitkub/bitkub',
          archived: false
        },
        {
          id: '/bunicorn/bunicorn-1',
          name: 'Bunicorn',
          url: 'https://hackenproof.com/bunicorn/bunicorn-1',
          archived: false
        },
        {
          id: '/coingecko/coingecko',
          name: 'CoinGecko',
          url: 'https://hackenproof.com/coingecko/coingecko',
          archived: false
        },
        {
          id: '/coinmetro/coinmetro-exchange',
          name: 'CoinMetro Exchange',
          url: 'https://hackenproof.com/coinmetro/coinmetro-exchange',
          archived: false
        },
        {
          id: '/coinsbit/coinsbit',
          name: 'Coinsbit',
          url: 'https://hackenproof.com/coinsbit/coinsbit',
          archived: false
        },
        {
          id: '/cryptology/cryptology',
          name: 'Cryptology',
          url: 'https://hackenproof.com/cryptology/cryptology',
          archived: false
        },
        {
          id: '/neverdie/neverdie-web',
          name: 'Neverdie Web',
          url: 'https://hackenproof.com/neverdie/neverdie-web',
          archived: true
        },
        {
          id: '/hacken-1/pentagon-hack',
          name: 'Pentagon HACK',
          url: 'https://hackenproof.com/hacken-1/pentagon-hack',
          archived: true
        },
        {
          id: '/ttc/ttc-mobile',
          name: 'TTC | Mobile',
          url: 'https://hackenproof.com/ttc/ttc-mobile',
          archived: true
        },
        {
          id: '/ttc/ttc-protocol',
          name: 'TTC | Protocol',
          url: 'https://hackenproof.com/ttc/ttc-protocol',
          archived: true
        },
        {
          id: '/ttc/ttc-sdk',
          name: 'TTC | SDK',
          url: 'https://hackenproof.com/ttc/ttc-sdk',
          archived: true
        },
        {
          id: '/tickets-travel-network/ttn-program',
          name: 'TTN Program',
          url: 'https://hackenproof.com/tickets-travel-network/ttn-program',
          archived: true
        },
        {
          id: '/unistake/unistake-smart-contracts',
          name: 'Unistake Smart Contracts',
          url: 'https://hackenproof.com/unistake/unistake-smart-contracts',
          archived: true
        },
        {
          id: '/vechain/vechainthor-vip191',
          name: 'VeChainThor VIP191',
          url: 'https://hackenproof.com/vechain/vechainthor-vip191',
          archived: true
        }
      ]
    )
  end

  it 'should fetch program scopes' do
    scopes = File.read('spec/fixtures/hackenproof/scopes.html')
    stub_request(:get, %r{/hacken/hackenproof}).with(headers: {host: 'hackenproof.com'})
      .to_return(status: 200, body: scopes)
    expect(subject.program_scopes(url: 'https://hackenproof.com/hacken/hackenproof')).to eq(
      targets: {
        in_scope: [
          {
            instruction: 'HackenProof main site',
            reward: 'Bounty',
            type: 'WEB',
            target: 'hackenproof.com',
            severity: 'Critical'
          }
        ],
        out_of_scope: [
          {
            target: 'blog.hackenproof.com',
            type: 'WEB',
            instruction: 'Our Blog',
            severity: 'None',
            reward: '--'
          }
        ]
      }
    )
  end
end
