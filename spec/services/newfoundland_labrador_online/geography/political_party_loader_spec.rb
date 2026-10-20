# frozen_string_literal: true

require 'rails_helper'

RSpec.describe NewfoundlandLabradorOnline::Geography::PoliticalPartyLoader do
  include RequestSpecHelper

  let(:liberal) { NewfoundlandLabradorOnline::PoliticalParty.find_by!(jurisdiction: 'provincial', identifier: 'liberal') }

  before { configure_host_platform }

  it 'loads the provincial parties with colours and attaches logos', :aggregate_failures do
    described_class.new.call

    expect(liberal.display_color).to match(/\A#\h{6}\z/)
    expect(liberal.logo).to be_attached
    expect(liberal.logo_license).to be_present
  end

  it 'is public so CE serves its logo to anonymous visitors' do
    described_class.new.call

    expect(liberal).to be_privacy_public
  end

  it 'is idempotent and keeps one attachment' do
    described_class.new.call

    counts = -> { [NewfoundlandLabradorOnline::PoliticalParty.count, ActiveStorage::Blob.count] }

    expect { described_class.new.call }.not_to(change(&counts))
  end

  describe 'party affiliation over time' do
    let(:district_path) { Rails.root.join('spec/fixtures/nl_regions/two_districts.geojson') }
    let(:elections_path) { Rails.root.join('spec/fixtures/nl_regions/two_elections.json') }
    let(:corner_brook) { NewfoundlandLabradorOnline::ProvincialElectoralDistrict.find_by!(identifier: 'nl-ped-corner-brook') }
    let(:term) { corner_brook.elected_terms.find_by!(ended_on: nil) }

    before do
      NewfoundlandLabradorOnline::Geography::ProvincialDistrictLoader.new(path: district_path).call
      described_class.new.call
      NewfoundlandLabradorOnline::Geography::ProvincialElectionLoader.new(path: elections_path).call
    end

    it 'derives a membership from the elected party' do
      expect(term.party_on).to eq(liberal)
    end

    def pc = NewfoundlandLabradorOnline::PoliticalParty.find_by!(identifier: 'pc')

    it 'follows a floor crossing recorded as a dated membership', :aggregate_failures do
      crossing = Date.new(2026, 9, 1)
      term.person.party_memberships.find_by!(ended_on: nil).update!(ended_on: crossing, end_reason: 'floor_crossing')
      term.person.party_memberships.create!(political_party: pc, started_on: crossing, start_reason: 'floor_crossing')

      expect(term.party_on(crossing - 1)).to eq(liberal)
      expect(term.party_on(crossing)).to eq(pc)
    end

    it 'rejects a membership that ends before it starts' do
      membership = term.person.party_memberships.build(political_party: pc, started_on: Date.new(2026, 1, 2),
                                                       ended_on: Date.new(2026, 1, 1))

      expect(membership).not_to be_valid
    end
  end
end
