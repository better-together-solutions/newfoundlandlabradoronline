# frozen_string_literal: true

require 'rails_helper'

RSpec.describe NewfoundlandLabradorOnline::Geography::PartyChangeLoader do
  include RequestSpecHelper

  let(:path) { Rails.root.join('spec/fixtures/nl_regions/party_changes.json') }
  let(:fixtures) { Rails.root.join('spec/fixtures/nl_regions') }
  let(:elections) do
    NewfoundlandLabradorOnline::Geography::ProvincialElectionLoader.new(path: fixtures.join('two_elections.json'))
  end
  let(:person) { BetterTogether::Person.find_by!(identifier: 'nl-mha-jim-parsons') }

  def party_rows
    party = NewfoundlandLabradorOnline::PoliticalParty
    parties = party.where.not(community_id: nil).index_by(&:community_id)
    memberships = BetterTogether::PersonCommunityMembership.where(member: person, joinable_id: parties.keys)
    memberships.order(:starts_at).map do |m|
      NewfoundlandLabradorOnline::Civic::PartyHolding.new(membership: m, political_party: parties[m.joinable_id])
    end
  end

  before do
    configure_host_platform
    districts = NewfoundlandLabradorOnline::Geography::ProvincialDistrictLoader
    districts.new(path: fixtures.join('two_districts.geojson')).call
    NewfoundlandLabradorOnline::Geography::PoliticalPartyLoader.new.call
    elections.call
  end

  it 'ends the old membership on the change date and starts the new one', :aggregate_failures do
    result = described_class.new(path:).call

    expect(result.applied).to eq(1)
    expect(party_rows.map { |m| [m.political_party.identifier, m.started_on.to_s, m.end_reason] })
      .to eq([%w[liberal 2025-10-14 floor_crossing], ['independent', '2026-09-14', nil]])
  end

  it 'is idempotent and survives an elections reload', :aggregate_failures do
    described_class.new(path:).call
    elections.call

    expect(described_class.new(path:).call.unchanged).to eq(1)
    expect(party_rows.size).to eq(2)
  end

  it 'reports roster entries that disagree with the loaded memberships' do
    result = described_class.new(path:).call

    expect(result.roster_mismatches).to eq(['Jim Parsons: roster "pc", loaded "independent"'])
  end
end
