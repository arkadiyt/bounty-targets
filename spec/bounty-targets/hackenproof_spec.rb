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
      [{id: '/hacken/hackenproof', name: 'HackenProof', url: 'https://hackenproof.com/hacken/hackenproof',
        archived: false},
       {id: '/kuna/kuna-crypto-exchange', name: 'Kuna Crypto Exchange',
        url: 'https://hackenproof.com/kuna/kuna-crypto-exchange', archived: false},
       {id: '/vechain/vechainthor', name: 'VeChainThor', url: 'https://hackenproof.com/vechain/vechainthor',
        archived: false},
       {id: '/vechain/vechainthor-wallet', name: 'VeChainThor Wallet',
        url: 'https://hackenproof.com/vechain/vechainthor-wallet', archived: false},
       {id: '/gate-dot-io/gate-dot-io-exchange', name: 'Gate.io Exchange',
        url: 'https://hackenproof.com/gate-dot-io/gate-dot-io-exchange', archived: false},
       {id: '/coingecko/coingecko', name: 'CoinGecko', url: 'https://hackenproof.com/coingecko/coingecko',
        archived: false},
       {id: '/p2pb2b/p2pb2b', name: 'P2PB2B', url: 'https://hackenproof.com/p2pb2b/p2pb2b',
        archived: false},
       {id: '/coinsbit/coinsbit', name: 'Coinsbit', url: 'https://hackenproof.com/coinsbit/coinsbit',
        archived: false},
       {id: '/hotbit/hotbit', name: 'Hotbit', url: 'https://hackenproof.com/hotbit/hotbit',
        archived: false},
       {id: '/whitebit/whitebit', name: 'WhiteBIT', url: 'https://hackenproof.com/whitebit/whitebit',
        archived: false},
       {id: '/vechain/vechainthor-vip191', name: 'VeChainThor VIP191',
        url: 'https://hackenproof.com/vechain/vechainthor-vip191', archived: true}]
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
