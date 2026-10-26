# frozen_string_literal: true

require 'rails_helper'

RSpec.describe NewfoundlandLabradorOnline::MembershipMandate do
  include RequestSpecHelper

  before { configure_host_platform }

  let(:membership) { join(create(:better_together_person), civic_community) }

  it 'validates kind and end reason', :aggregate_failures do
    expect(described_class.new(membership:, kind: 'elected', end_reason: 'defeated')).to be_valid
    expect(described_class.new(membership:, kind: 'crowned')).not_to be_valid
    expect(described_class.new(membership:, kind: 'elected', end_reason: 'bored')).not_to be_valid
  end

  it 'allows one mandate per membership' do
    described_class.create!(membership:, kind: 'elected')

    expect(described_class.new(membership:, kind: 'appointed')).not_to be_valid
  end

  it 'attaches to the membership', :aggregate_failures do
    mandate = described_class.create!(membership:, kind: 'appointed', title: 'Minister of Finance')

    expect(membership.reload.mandate).to eq(mandate)
  end

  describe NewfoundlandLabradorOnline::CommunitySeat do
    let(:body) { civic_community }

    it 'requires a represented community only for representing seats', :aggregate_failures do
      expect(described_class.new(community: body, name: 'A', kind: 'representing')).not_to be_valid
      expect(described_class.new(community: body, name: 'B', kind: 'at_large', represents_community: body))
        .not_to be_valid
      expect(described_class.new(community: body, name: 'C', kind: 'officer')).to be_valid
    end

    it 'keeps names unique within a body' do
      described_class.create!(community: body, name: 'Chair', kind: 'officer')

      expect(described_class.new(community: body, name: 'Chair', kind: 'officer')).not_to be_valid
    end
  end
end
