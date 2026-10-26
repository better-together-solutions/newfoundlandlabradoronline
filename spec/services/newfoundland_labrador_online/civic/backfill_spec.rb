# frozen_string_literal: true

require 'rails_helper'

RSpec.describe NewfoundlandLabradorOnline::Civic::Backfill do
  include RequestSpecHelper

  let(:nlo) { NewfoundlandLabradorOnline }
  let(:membership_class) { BetterTogether::PersonCommunityMembership }
  let(:packets) { Rails.root.join('spec/fixtures/nl_regions') }

  # Builds the legacy rows (elected terms, party memberships) from what the loaders wrote, then removes the new
  # records so the backfill starts from the pre-migration state.
  before do
    configure_host_platform
    load_packets
    legacy_from_memberships
    membership_class.where.not(starts_at: nil).destroy_all
  end

  def load_packets
    geography = nlo::Geography
    geography::ProvincialDistrictLoader.new(path: packets.join('two_districts.geojson')).call
    geography::PoliticalPartyLoader.new.call
    geography::ProvincialElectionLoader.new(path: packets.join('two_elections.json')).call
  end

  def legacy_from_memberships
    nlo::Civic::Roster.seat_memberships.includes(:mandate, :member).find_each { |m| legacy_term(m) }
    party_ids = nlo::PoliticalParty.pluck(:community_id, :id).to_h
    membership_class.where(joinable_id: party_ids.keys).find_each { |m| legacy_party(m, party_ids[m.joinable_id]) }
  end

  def legacy_party(membership, party_id)
    nlo::PartyMembership.create!(person_id: membership.member_id, political_party_id: party_id,
                                 started_on: dates(membership).first, ended_on: dates(membership).last,
                                 start_reason: 'elected')
  end

  def legacy_term(membership)
    candidacy = nlo::Candidacy.find(membership.mandate.conferred_by_id)
    nlo::ElectedTerm.create!(legacy_term_attributes(membership, candidacy))
  end

  def legacy_term_attributes(membership, candidacy)
    { person_id: membership.member_id, region_id: membership.mandate.seat_id, candidacy:, office: 'mha',
      election: candidacy.electoral_contest.election, party_name: candidacy.party_name,
      political_party: candidacy.political_party, started_on: dates(membership).first,
      ended_on: dates(membership).last, end_reason: membership.ends_at && 'next_election' }
  end

  def dates(membership)
    [membership.starts_at, membership.ends_at].map { |time| nlo::Civic.local_date(time) }
  end

  it 'rolls back everything on a dry run' do
    expect { described_class.call }.not_to(change(membership_class, :count))
  end

  it 'converts every term and party membership when writing', :aggregate_failures do
    result = described_class.call(write: true)

    expect(result.errors).to be_empty
    expect(result.terms).to eq(nlo::ElectedTerm.count)
    expect(result.party_memberships).to eq(nlo::PartyMembership.count)
    expect(nlo::Civic::ParityReport.call).to be_empty
  end

  it 'is idempotent' do
    described_class.call(write: true)

    expect { described_class.call(write: true) }.not_to(change(membership_class, :count))
  end

  it 'sends no notifications' do
    expect { described_class.call(write: true) }.not_to(change(Noticed::Event, :count))
  end
end
