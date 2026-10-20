# frozen_string_literal: true

require 'rails_helper'

RSpec.describe NewfoundlandLabradorOnline::SubtypeResourceTypes do
  include RequestSpecHelper

  before { configure_host_platform }

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
