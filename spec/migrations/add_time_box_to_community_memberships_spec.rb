# frozen_string_literal: true

require 'rails_helper'
require Rails.root.join('db/migrate/20261021000000_add_time_box_to_community_memberships')
require Rails.root.join('db/migrate/20261021010000_create_membership_mandates_and_community_seats')
require Rails.root.join('db/migrate/20261021020000_create_community_associations')
require Rails.root.join('db/migrate/20261021030000_create_legislature_details')

RSpec.describe AddTimeBoxToCommunityMemberships do
  let(:connection) { ActiveRecord::Base.connection }

  it 'are idempotent when run again', :aggregate_failures do
    [described_class, CreateMembershipMandatesAndCommunitySeats, CreateCommunityAssociations,
     CreateLegislatureDetails].each do |migration|
      expect { ActiveRecord::Migration.suppress_messages { migration.new.migrate(:up) } }.not_to raise_error
    end
  end

  it 'swaps the unique membership index', :aggregate_failures do
    table = :better_together_person_community_memberships

    expect(connection.index_name_exists?(table, 'unique_person_community_membership_member_role_start')).to be(true)
    expect(connection.index_name_exists?(table, 'unique_person_community_membership_member_role')).to be(false)
  end
end
