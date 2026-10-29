# frozen_string_literal: true

require 'rails_helper'

# The packet in db/data/nl_regions seeds straight into the civic model on a fresh install.
RSpec.describe NewfoundlandLabradorOnline::ElectoralSeed do
  include RequestSpecHelper

  let(:counts) do
    { districts: NewfoundlandLabradorOnline::ProvincialElectoralDistrict.count,
      parties: NewfoundlandLabradorOnline::PoliticalParty.count,
      elections: NewfoundlandLabradorOnline::Election.count,
      candidacies: NewfoundlandLabradorOnline::Candidacy.count,
      seats: NewfoundlandLabradorOnline::Civic::Roster.seat_memberships.count,
      mandates: NewfoundlandLabradorOnline::MembershipMandate.count }
  end

  before do
    configure_host_platform
    create(:navigation_area, identifier: 'platform-header') unless
      BetterTogether::NavigationArea.exists?(identifier: 'platform-header')
  end

  # rubocop:disable-next RSpec/ExampleLength
  it 'seeds the packet, and a second run changes nothing', :aggregate_failures do
    described_class.call
    first = counts
    summaries = described_class.call

    expect(first).to include(districts: 40, parties: 5, elections: 4, candidacies: 488, seats: 160)
    expect(counts).to eq(first)
    expect(summaries.keys).to eq(%i[roles districts parties elections party_changes navigation])
  end

  it 'names the missing set-up when there is no host platform' do
    allow(BetterTogether::Platform).to receive(:exists?).with(host: true).and_return(false)

    expect { described_class.call }.to raise_error(described_class::MissingPrerequisite, /Set up the platform/)
  end
end
