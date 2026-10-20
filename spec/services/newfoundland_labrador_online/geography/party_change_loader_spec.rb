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
    expect(person.party_memberships.chronological.map { |m| [m.political_party.identifier, m.started_on.to_s] })
      .to eq([%w[liberal 2025-10-14], %w[independent 2026-09-14]])
    expect(person.party_memberships.chronological.first.end_reason).to eq('floor_crossing')
  end

  it 'is idempotent and survives an elections reload', :aggregate_failures do
    described_class.new(path:).call
    elections.call

    expect(described_class.new(path:).call.unchanged).to eq(1)
    expect(person.party_memberships.count).to eq(2)
  end

  it 'reports roster entries that disagree with the loaded memberships' do
    result = described_class.new(path:).call

    expect(result.roster_mismatches).to eq(['Jim Parsons: roster "pc", loaded "independent"'])
  end
end
