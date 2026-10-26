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
    let(:corner_brook) { NewfoundlandLabradorOnline::ProvincialElectoralDistrict.find_by!(identifier: 'nl-ped-corner-brook') }
    let(:writer) { NewfoundlandLabradorOnline::Civic::Writer.new }
    let(:crossing) { Date.new(2026, 9, 1) }

    before do
      geography = NewfoundlandLabradorOnline::Geography
      fixtures = Rails.root.join('spec/fixtures/nl_regions')
      geography::ProvincialDistrictLoader.new(path: fixtures.join('two_districts.geojson')).call
      described_class.new.call
      geography::ProvincialElectionLoader.new(path: fixtures.join('two_elections.json')).call
    end

    def holding = NewfoundlandLabradorOnline::Civic::Roster.current_holdings(region_ids: [corner_brook.id]).first

    def pc = NewfoundlandLabradorOnline::PoliticalParty.find_by!(identifier: 'pc')

    def cross_floor
      current = NewfoundlandLabradorOnline::Civic::Roster.party_membership_on(holding.person, Time.current)
      writer.end_membership(current, on: crossing, reason: 'floor_crossing')
      writer.join_party(person: holding.person, party: pc, from: crossing, start_reason: 'floor_crossing')
    end

    it 'gives every party a community' do
      expect(liberal.community).to be_a(NewfoundlandLabradorOnline::PartyCommunity)
    end

    it 'derives a membership from the elected party' do
      expect(holding.party_on).to eq(liberal)
    end

    it 'follows a floor crossing recorded as a dated membership', :aggregate_failures do
      cross_floor

      expect(holding.party_on(crossing - 1)).to eq(liberal)
      expect(holding.party_on(crossing)).to eq(pc)
    end

    it 'rejects a membership that ends before it starts' do
      expect { writer.join_party(person: holding.person, party: pc, from: crossing, to: crossing - 1) }
        .to raise_error(ActiveRecord::RecordInvalid)
    end
  end
end
