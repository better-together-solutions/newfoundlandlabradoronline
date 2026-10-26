# frozen_string_literal: true

require 'rails_helper'

RSpec.describe NewfoundlandLabradorOnline::Civic::RoleSeeder do
  include RequestSpecHelper

  before { configure_host_platform }

  let(:role_count) { described_class::ROLES.values.sum(&:size) }

  it 'seeds inert roles idempotently', :aggregate_failures do
    expect { described_class.call }.to change(BetterTogether::Role, :count).by(role_count)
    expect { described_class.call }.not_to change(BetterTogether::Role, :count)

    role = BetterTogether::Role.find_by(identifier: 'director')
    expect(role.resource_permissions).to be_empty
    expect(Mobility.with_locale(:fr) { role.name }).to eq('Administrateur')
  end

  it 'offers no civic role to ordinary communities' do
    described_class.call

    expect(BetterTogether::Role.for_class(BetterTogether::Community).pluck(:identifier) &
           described_class::ROLES.values.flat_map(&:keys)).to be_empty
  end

  it 'scopes each role to its own community subtype', :aggregate_failures do
    described_class.call

    expect(BetterTogether::Role.find_by(identifier: 'party_leader').resource_type)
      .to eq('NewfoundlandLabradorOnline::PartyCommunity')
    expect(BetterTogether::Role.for_class(NewfoundlandLabradorOnline::LegislatureCommunity).pluck(:identifier))
      .to include('legislature_member', 'legislature_speaker')
  end

  it 're-scopes roles seeded earlier as generic community roles' do
    create(:better_together_role, :community_role, identifier: 'party_member')

    described_class.call

    expect(BetterTogether::Role.find_by(identifier: 'party_member').resource_type)
      .to eq('NewfoundlandLabradorOnline::PartyCommunity')
  end
end
