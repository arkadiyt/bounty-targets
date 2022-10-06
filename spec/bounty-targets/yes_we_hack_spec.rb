# frozen_string_literal: true

describe BountyTargets::YesWeHack do
  subject(:client) { described_class.new }

  before :all do
    described_class.make_all_methods_public!
  end

  it 'fetches a list of programs' do
    programs = File.read('spec/fixtures/yes_we_hack/programs.json')
    stub_request(:get, %r{/programs}).with(headers: {host: 'api.yeswehack.com'})
      .to_return(status: 200, body: programs)
    expect(client.directory_index).to eq(
      [
        {
          disabled: false,
          id: 'stopcovid-bugbounty-program',
          managed: false,
          max_bounty: 2000,
          min_bounty: 0,
          name: 'StopCovid France Bug Bounty program',
          public: true
        }
      ]
    )
  end

  it 'fetches program scopes' do
    scopes = File.read('spec/fixtures/yes_we_hack/scopes.json')
    stub_request(:get, %r{/programs/stopcovid-bugbounty-program})
      .with(headers: {host: 'api.yeswehack.com'}).to_return(status: 200, body: scopes)
    expect(client.program_scopes(id: 'stopcovid-bugbounty-program')).to eq(
      targets: {
        in_scope: [
          {
            target: 'https://play.google.com/store/apps/details?id=fr.gouv.android.stopcovid',
            type: 'mobile-application-android'
          },
          {
            target: 'https://apps.apple.com/fr/app/stopcovid-france/id1511279125',
            type: 'mobile-application-ios'
          },
          {
            target: 'api.stopcovid.gouv.fr',
            type: 'api'
          },
          {
            target: 'app.stopcovid.gouv.fr',
            type: 'api'
          },
          {
            target: 'bonjour.stopcovid.gouv.fr',
            type: 'api'
          }
        ],
        out_of_scope: [
          {
            target: 'Everything that is not part of the scope',
            type: 'other'
          }
        ]
      }
    )
  end
end
