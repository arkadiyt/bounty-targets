# frozen_string_literal: true

require 'bounty-targets/bountygraph'

describe BountyTargets::Bountygraph do
  before :all do
    BountyTargets::Bountygraph.make_all_methods_public!
  end

  let(:subject) { BountyTargets::Bountygraph.new }

  it 'should fetch a list of programs' do
    programs = IO.read('spec/fixtures/bountygraph/programs.html')
    stub_request(:get, 'https://bountygraph.com/programs').to_return(status: 200, body: programs)
    expect(subject.directory_index).to eq([
      {
        id: 'bountygraph',
        name: 'BountyGraph',
        description: 'Helping make open-source software secure through crowdfunded bug bounties and audits.'
      },
      {
        id: 'curl',
        name: 'curl',
        description: 'curl is a command line tool and libcurl is a library - for transferring data with URLs. curl\'s official web site is https://curl.haxx.se'
      },
      {
        id: 'gnu-wget',
        name: 'GNU Wget',
        description: 'GNU Wget / Wget2 is a free software package for retrieving files using HTTP, HTTPS, FTP and FTPS: the most widely-used Internet protocols.'
      },
      {
        id: 'squid',
        name: 'Squid',
        description: 'Squid is a popular open source web caching proxy'
      }
    ])
  end

  it 'should fetch program scopes' do
    program = IO.read('spec/fixtures/bountygraph/scopes.html')
    stub_request(:get, 'https://bountygraph.com/programs/bountygraph').to_return(status: 200, body: program)
    expect(subject.program_scopes(id: 'bountygraph')).to eq(
      targets: {
        in_scope: ['bountygraph.com', '*.bountygraph.com'],
        out_of_scope: []
      }
    )
  end
end
