# frozen_string_literal: true

require 'rails_helper'

RSpec.describe NewfoundlandLabradorOnline::PartyCommunity do
  include RequestSpecHelper

  before { configure_host_platform }

  it 'loads each subtype through the Community base class', :aggregate_failures do
    legislature = civic_community(NewfoundlandLabradorOnline::LegislatureCommunity)

    found = BetterTogether::Community.find(legislature.id)
    expect(found).to be_a(NewfoundlandLabradorOnline::LegislatureCommunity)
    expect(found.type).to eq('NewfoundlandLabradorOnline::LegislatureCommunity')
  end

  it 'behaves as a Community to routes and policies', :aggregate_failures do
    committee = civic_community(NewfoundlandLabradorOnline::CommitteeCommunity)

    expect(committee.class.model_name.to_s).to eq('BetterTogether::Community')
    expect(Pundit::PolicyFinder.new(committee).policy).to eq(BetterTogether::CommunityPolicy)
  end

  it 'uses the community member role as the default role' do
    role = BetterTogether::Role.find_by(identifier: 'community_member', resource_type: 'BetterTogether::Community') ||
           create(:better_together_role, :community_role, identifier: 'community_member')
    party = civic_community(described_class)

    expect(party.default_member_role).to eq(role)
  end

  it 'stores legislature details' do
    legislature = civic_community(NewfoundlandLabradorOnline::LegislatureCommunity)
    detail = legislature.create_legislature_detail!(level: 'provincial', seat_count: 40, member_title: 'MHA')

    expect(legislature.reload.legislature_detail).to eq(detail)
  end

  it 'lets roles and permissions be scoped to a community subtype', :aggregate_failures do
    role = build(:better_together_role, :community_role, resource_type: 'NewfoundlandLabradorOnline::PartyCommunity')
    permission = build(:better_together_resource_permission,
                       resource_type: 'NewfoundlandLabradorOnline::PartyCommunity')

    expect(role).to be_valid
    expect(permission).to be_valid
  end

  it 'still rejects unknown resource types', :aggregate_failures do
    expect(build(:better_together_role, :community_role, resource_type: 'Kernel')).not_to be_valid
    expect(build(:better_together_resource_permission, resource_type: 'Kernel')).not_to be_valid
  end

  it 'labels subtype role tabs for the roles page' do
    helper = Class.new { include BetterTogether::RolesHelper }.new

    expect(helper.role_resource_type_label('NewfoundlandLabradorOnline::PartyCommunity')).to eq('Party roles')
  end
end
