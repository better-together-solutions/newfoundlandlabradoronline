# frozen_string_literal: true

require 'rails_helper'

RSpec.describe NewfoundlandLabradorOnline::Civic::MunicipalRosterLoader do
  include RequestSpecHelper

  before { configure_host_platform }

  let!(:settlement) { create(:geography_settlement, name: 'Testville') }
  let(:packet) do
    { 'councils' => [{ 'settlement' => settlement.slug, 'statcan_csd' => '9999999', 'municipal_status' => 'town',
                       'status_authority' => 'Test directory', 'council_name' => 'Testville Town Council',
                       'seat_count' => 3, 'seats' => [{ 'name' => 'Ward 1', 'position' => 1 }],
                       'officials' => officials }] }
  end
  let(:officials) do
    [{ 'name' => 'Ann Mayor', 'role' => 'head', 'title' => 'Mayor', 'from' => '2025-10-02' },
     { 'name' => 'Bo Ward', 'role' => 'member', 'title' => 'Ward 1 Councillor', 'seat' => 'Ward 1' }]
  end
  let(:path) do
    Rails.root.join("tmp/councils_spec_#{SecureRandom.hex(4)}.json").tap { |file| File.write(file, packet.to_json) }
  end

  after { FileUtils.rm_f(path) }

  def run(apply)
    described_class.new(path:, apply:).call
  end

  it 'writes nothing on a dry run but reports what it would do', :aggregate_failures do
    result = run(false)

    expect(result).to have_attributes(councils: 1, people: 2, offices: 2)
    expect(NewfoundlandLabradorOnline::LegislatureCommunity.count).to eq(0)
    expect(BetterTogether::Person.where('identifier LIKE ?', 'nl-municipal-%')).to be_none
  end

  it 'creates the council, seats, people and dated memberships on apply', :aggregate_failures do
    run(true)
    council = NewfoundlandLabradorOnline::LegislatureCommunity.last

    expect(council.legislature_detail).to have_attributes(body_kind: 'council', seat_count: 3)
    expect(council.person_community_memberships.count).to eq(2)
    expect(settlement.reload.identifier_for('statcan_csd')).to eq('9999999')
  end

  it 'records the municipal status from the packet' do
    run(true)

    expect(settlement.reload.current_status.municipal_status).to eq('town')
  end

  it 'is idempotent', :aggregate_failures do
    run(true)

    counts = -> { [BetterTogether::PersonCommunityMembership.count, BetterTogether::Person.count] }

    expect { run(true) }.not_to(change(&counts))
  end

  it 'reports a settlement it cannot find', :aggregate_failures do
    packet['councils'].first.merge!('settlement' => 'nowhere', 'statcan_csd' => nil)

    expect(run(true).missing_settlements).to eq(['nowhere'])
  end
end
