# frozen_string_literal: true

describe BountyTargets::Hackenproof do
  before :all do
    BountyTargets::Hackenproof.make_all_methods_public!
  end

  let(:subject) { BountyTargets::Hackenproof.new }

  it 'should fetch a list of programs' do
    programs = IO.read('spec/fixtures/hackenproof/programs.html')
    stub_request(:get, %r{/programs}).with(headers: {host: 'hackenproof.com'}).to_return(status: 200, body: programs)

    expect(subject.directory_index).to eq(
      [
        {
          id: '/crypviser/crypviser-network',
          name: 'Crypviser Network',
          url: 'https://hackenproof.com/crypviser/crypviser-network',
          archived: true
        },
        {
          id: '/crypviser/crypviser-secure-messenger',
          name: 'Crypviser Secure Messenger',
          url: 'https://hackenproof.com/crypviser/crypviser-secure-messenger',
          archived: true
        },
        {
          id: '/neverdie/dragon-king',
          name: 'Dragon King',
          url: 'https://hackenproof.com/neverdie/dragon-king',
          archived: true
        },
        {
          id: '/enecuum/enecuum',
          name: 'Enecuum',
          url: 'https://hackenproof.com/enecuum/enecuum',
          archived: true
        },
        {
          id: '/hacken/hackit-4-dot-0',
          name: 'HackIT 4.0',
          url: 'https://hackenproof.com/hacken/hackit-4-dot-0',
          archived: true
        },
        {
          id: '/hacken/hackenproof',
          name: 'HackenProof',
          url: 'https://hackenproof.com/hacken/hackenproof',
          archived: false
        },
        {
          id: '/interkassa/interkassa-ltd',
          name: 'Interkassa ltd',
          url: 'https://hackenproof.com/interkassa/interkassa-ltd',
          archived: true
        },
        {
          id: '/kuna/kuna-crypto-exchange',
          name: 'Kuna crypto exchange',
          url: 'https://hackenproof.com/kuna/kuna-crypto-exchange',
          archived: false
        },
        {
          id: '/neverdie/neverdie-smart-contract',
          name: 'Neverdie Smart Contract',
          url: 'https://hackenproof.com/neverdie/neverdie-smart-contract',
          archived: true
        },
        {
          id: '/neverdie/neverdie-web',
          name: 'Neverdie Web',
          url: 'https://hackenproof.com/neverdie/neverdie-web',
          archived: true
        },
        {
          id: '/ttc/ttc-mobile',
          name: 'TTC | Mobile',
          url: 'https://hackenproof.com/ttc/ttc-mobile',
          archived: false
        },
        {
          id: '/ttc/ttc-protocol',
          name: 'TTC | Protocol',
          url: 'https://hackenproof.com/ttc/ttc-protocol',
          archived: false
        },
        {
          id: '/ttc/ttc-sdk',
          name: 'TTC | SDK',
          url: 'https://hackenproof.com/ttc/ttc-sdk',
          archived: false
        },
        {
          id: '/vechain/vechainthor',
          name: 'VeChainThor',
          url: 'https://hackenproof.com/vechain/vechainthor',
          archived: false
        },
        {
          id: '/vechain/vechainthor-wallet',
          name: 'VeChainThor Wallet',
          url: 'https://hackenproof.com/vechain/vechainthor-wallet',
          archived: false
        },
        {
          id: '/everitoken/everitoken-blockchain',
          name: 'everiToken | blockchain',
          url: 'https://hackenproof.com/everitoken/everitoken-blockchain',
          archived: false
        }
      ]
    )
  end

  it 'should fetch program scopes' do
    scopes = IO.read('spec/fixtures/hackenproof/scopes.html')
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
