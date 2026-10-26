# frozen_string_literal: true

# Memberships gain start and end datetimes (both optional: no dates means an open-ended membership, as before).
# The unique index adds starts_at so one person can hold the same role in successive terms.
class AddTimeBoxToCommunityMemberships < ActiveRecord::Migration[8.1]
  TABLE = :better_together_person_community_memberships
  OLD_INDEX = 'unique_person_community_membership_member_role'
  NEW_INDEX = 'unique_person_community_membership_member_role_start'
  WINDOW_INDEX = 'person_community_membership_by_joinable_window'
  CHECK = 'person_community_membership_window_order'
  CHECK_SQL = 'ends_at IS NULL OR starts_at IS NULL OR ends_at > starts_at'

  def up
    add_column TABLE, :starts_at, :datetime unless column_exists?(TABLE, :starts_at)
    add_column TABLE, :ends_at, :datetime unless column_exists?(TABLE, :ends_at)
    add_check_constraint TABLE, CHECK_SQL, name: CHECK unless check_constraint_exists?(TABLE, name: CHECK)
    remove_index TABLE, name: OLD_INDEX if index_name_exists?(TABLE, OLD_INDEX)
    add_window_indexes
  end

  def down
    guard_duplicates
    remove_index TABLE, name: WINDOW_INDEX if index_name_exists?(TABLE, WINDOW_INDEX)
    remove_index TABLE, name: NEW_INDEX if index_name_exists?(TABLE, NEW_INDEX)
    restore_old_index
    remove_check_constraint TABLE, name: CHECK if check_constraint_exists?(TABLE, name: CHECK)
    remove_column TABLE, :ends_at if column_exists?(TABLE, :ends_at)
    remove_column TABLE, :starts_at if column_exists?(TABLE, :starts_at)
  end

  private

  def add_window_indexes
    unless index_name_exists?(TABLE, NEW_INDEX)
      add_index TABLE, %i[joinable_id member_id role_id starts_at],
                unique: true, nulls_not_distinct: true, name: NEW_INDEX
    end
    return if index_name_exists?(TABLE, WINDOW_INDEX)

    add_index TABLE, %i[joinable_id starts_at ends_at], name: WINDOW_INDEX
  end

  def restore_old_index
    return if index_name_exists?(TABLE, OLD_INDEX)

    add_index TABLE, %i[joinable_id member_id role_id], unique: true, name: OLD_INDEX
  end

  def guard_duplicates
    dupes = select_value(<<~SQL.squish).to_i
      SELECT COUNT(*) FROM (SELECT 1 FROM #{TABLE} GROUP BY joinable_id, member_id, role_id HAVING COUNT(*) > 1) d
    SQL
    return if dupes.zero?

    raise ActiveRecord::IrreversibleMigration,
          "#{dupes} person/community/role groups hold more than one dated membership; merge them before rolling back"
  end
end
