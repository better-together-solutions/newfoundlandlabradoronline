# frozen_string_literal: true

require 'rails_helper'

RSpec.describe NewfoundlandLabradorOnline::EventHosting do
  include RequestSpecHelper

  before { configure_host_platform }

  let(:creator) { create(:better_together_person) }
  let(:community) { create(:better_together_community) }
  let(:other) { create(:better_together_community) }
  let(:event) { build(:better_together_event, creator:, event_hosts: []) }

  it 'hosts the event by the community and not by the creator', :aggregate_failures do
    event.host_community_id = community.id
    event.save!

    expect(event.event_hosts.map(&:host)).to eq([community])
    expect(event.host_community_id).to eq(community.id)
  end

  it 'still defaults to the creator when no host is given', :aggregate_failures do
    event.save!

    expect(event.event_hosts.map(&:host)).to eq([creator])
  end

  it 'changes the host on update', :aggregate_failures do
    event.host_community_id = community.id
    event.save!

    event.update!(host_community_id: other.id)

    expect(event.reload.event_hosts.map(&:host)).to eq([other])
    expect(BetterTogether::EventHost.where(event_id: event.id).count).to eq(1)
  end

  it 'leaves the host alone when the same community is set again', :aggregate_failures do
    event.host_community_id = community.id
    event.save!

    expect { event.update!(host_community_id: community.id) }.not_to(change { event.reload.event_hosts.pluck(:id) })
  end

  it 'rejects an unknown community', :aggregate_failures do
    event.host_community_id = SecureRandom.uuid

    expect(event).not_to be_valid
    expect(event.errors[:host_community_id]).to be_present
  end
end
