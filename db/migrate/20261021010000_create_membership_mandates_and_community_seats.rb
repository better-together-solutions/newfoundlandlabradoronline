# frozen_string_literal: true

# What a membership rests on (election, appointment, ex officio) and the seats a community offers.
class CreateMembershipMandatesAndCommunitySeats < ActiveRecord::Migration[8.1]
  def up
    create_community_seats unless table_exists?(:community_seats)
    create_membership_mandates unless table_exists?(:membership_mandates)
  end

  def down
    drop_table :membership_mandates, if_exists: true
    drop_table :community_seats, if_exists: true
  end

  private

  def create_community_seats # rubocop:disable Metrics/MethodLength
    create_table :community_seats, id: :uuid do |t|
      t.integer :lock_version, default: 0, null: false
      t.timestamps
      t.references :community, type: :uuid, null: false, index: true,
                               foreign_key: { to_table: :better_together_communities }
      t.references :represents_community, type: :uuid, null: true, index: true,
                                          foreign_key: { to_table: :better_together_communities }
      t.string :name, null: false
      t.string :kind, null: false, default: 'at_large', limit: 30
      t.integer :position, null: false, default: 0
      t.index %i[community_id name], unique: true, name: 'index_community_seats_on_community_and_name'
    end
  end

  def create_membership_mandates # rubocop:disable Metrics/MethodLength
    create_table :membership_mandates, id: :uuid do |t|
      t.integer :lock_version, default: 0, null: false
      t.timestamps
      t.references :membership, type: :uuid, null: false, index: { unique: true },
                                foreign_key: { to_table: :better_together_person_community_memberships }
      t.string :kind, null: false, limit: 30
      t.string :seat_type
      t.uuid :seat_id
      t.string :conferred_by_type
      t.uuid :conferred_by_id
      t.string :title
      t.string :end_reason, limit: 50
      t.index %i[seat_type seat_id], name: 'index_membership_mandates_on_seat'
      t.index %i[conferred_by_type conferred_by_id], name: 'index_membership_mandates_on_conferred_by'
    end
  end
end
