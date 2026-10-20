# frozen_string_literal: true

require 'rails_helper'

RSpec.describe NewfoundlandLabradorOnline::MembershipTimeBox do
  # rubocop:disable RSpec/ExampleLength, RSpec/MultipleExpectations
  include RequestSpecHelper

  before { configure_host_platform }

  let(:person) { create(:better_together_person) }
  let(:community) { civic_community }
  let(:role) { civic_role }
  let(:t0) { Time.zone.local(2020, 1, 1) }

  it 'leaves undated memberships open ended and active', :aggregate_failures do
    membership = join(person, community)

    expect(membership.current?).to be(true)
    expect(BetterTogether::PersonCommunityMembership.active).to include(membership)
    expect(BetterTogether::PersonCommunityMembership.current).to include(membership)
  end

  it 'allows the same role in successive terms', :aggregate_failures do
    first = join(person, community, starts_at: t0, ends_at: t0 + 4.years)
    second = join(person, community, starts_at: t0 + 4.years, ends_at: t0 + 8.years)

    expect(first).to be_persisted
    expect(second).to be_persisted
    expect(community.person_community_memberships.held_on(t0 + 5.years)).to contain_exactly(second)
  end

  it 'rejects overlapping holdings of one role' do
    join(person, community, starts_at: t0, ends_at: t0 + 4.years)
    overlap = BetterTogether::PersonCommunityMembership.new(member: person, joinable: community, role:,
                                                            status: 'active', starts_at: t0 + 3.years)

    expect(overlap).not_to be_valid
    expect(overlap.errors[:role_id]).to be_present
  end

  it 'rejects a window that ends before it starts' do
    bad = BetterTogether::PersonCommunityMembership.new(member: person, joinable: community, role:,
                                                        status: 'active', starts_at: t0, ends_at: t0 - 1.day)

    expect(bad).not_to be_valid
  end

  it 'excludes ended and future memberships from .active', :aggregate_failures do
    ended = join(person, community, starts_at: 3.years.ago, ends_at: 1.year.ago)
    future = join(create(:better_together_person), community, starts_at: 1.year.from_now)
    scope = BetterTogether::PersonCommunityMembership.active

    expect(scope).not_to include(ended, future)
    expect(BetterTogether::PersonCommunityMembership.former).to include(ended)
    expect(BetterTogether::PersonCommunityMembership.upcoming).to include(future)
  end

  it 'converts calendar dates to local midnight in Newfoundland' do
    stamp = BetterTogether::PersonCommunityMembership.local_midnight(Date.new(2025, 10, 14))

    expect(stamp.time_zone.name).to eq('America/St_Johns')
    expect([stamp.hour, stamp.min]).to eq([0, 0])
  end

  describe 'notifications' do
    it 'stays quiet when skip_notifications is set' do
      allow(BetterTogether::MembershipNotificationService).to receive(:new).and_call_original

      join(person, community, skip_notifications: true)

      expect(BetterTogether::MembershipNotificationService).not_to have_received(:new)
    end

    it 'still notifies by default' do
      allow(BetterTogether::MembershipNotificationService).to receive(:new).and_call_original

      join(person, community)

      expect(BetterTogether::MembershipNotificationService).to have_received(:new).at_least(:once)
    end
  end

  describe 'permission cache' do
    around do |example|
      adapter = ActiveJob::Base.queue_adapter
      ActiveJob::Base.queue_adapter = :test
      example.run
      ActiveJob::Base.queue_adapter = adapter
    end

    it 'schedules a cache expiry at the end of a future window' do
      expect { join(person, community, starts_at: Time.current, ends_at: 1.week.from_now) }
        .to have_enqueued_job(NewfoundlandLabradorOnline::ExpireMemberPermissionCacheJob).with(person.id)
    end
  end

  describe 'cascade_end' do
    it 'ends dependent memberships when the source membership ends', :aggregate_failures do
      legislature = civic_community(NewfoundlandLabradorOnline::LegislatureCommunity)
      cabinet = civic_community(NewfoundlandLabradorOnline::ExecutiveCommunity)
      associate(legislature, cabinet, 'drawn_from', cascade_end: true)
      seat = join(person, legislature, role: civic_role('legislature_member'), starts_at: t0)
      minister = join(person, cabinet, role: civic_role('executive_member'), starts_at: t0 + 1.day)

      seat.update!(ends_at: t0 + 2.years)

      expect(minister.reload.ends_at).to eq(t0 + 2.years)
    end
  end
  # rubocop:enable RSpec/ExampleLength, RSpec/MultipleExpectations
end
