# frozen_string_literal: true

# Ties provincial data to the province in the geography tables (BetterTogether::Geography::State, iso_code CA-NL)
# instead of encoding it in the jurisdiction string, and backfills the existing Newfoundland and Labrador rows.
class AddStateToPartiesAndElections < ActiveRecord::Migration[8.1]
  NL = "(SELECT id FROM better_together_geography_states WHERE iso_code = 'CA-NL')"
  OLD_PARTY_INDEX = 'index_political_parties_on_jurisdiction_and_identifier'
  OLD_ELECTION_INDEX = 'index_elections_on_jurisdiction_and_held_on'
  PARTY_INDEX = 'index_political_parties_on_jurisdiction_state_identifier'
  ELECTION_INDEX = 'index_elections_on_jurisdiction_state_held_on'

  def up
    add_state_column(:political_parties)
    add_state_column(:elections)
    backfill
    swap_unique_indexes
  end

  def down
    remove_index :political_parties, name: PARTY_INDEX, if_exists: true
    remove_index :elections, name: ELECTION_INDEX, if_exists: true
    execute "UPDATE political_parties SET jurisdiction = 'provincial-nl' WHERE jurisdiction = 'provincial'"
    add_index :political_parties, %i[jurisdiction identifier], unique: true, name: OLD_PARTY_INDEX, if_not_exists: true
    add_index :elections, %i[jurisdiction held_on], unique: true, name: OLD_ELECTION_INDEX, if_not_exists: true
    remove_column :political_parties, :state_id if column_exists?(:political_parties, :state_id)
    remove_column :elections, :state_id if column_exists?(:elections, :state_id)
  end

  private

  def add_state_column(table)
    return if column_exists?(table, :state_id)

    add_reference table, :state, type: :uuid, null: true, index: true,
                                 foreign_key: { to_table: :better_together_geography_states }
  end

  def backfill
    execute <<~SQL.squish
      UPDATE political_parties SET jurisdiction = 'provincial', state_id = #{NL} WHERE jurisdiction = 'provincial-nl'
    SQL
    execute "UPDATE elections SET state_id = #{NL} WHERE jurisdiction = 'provincial' AND state_id IS NULL"
    execute <<~SQL.squish
      UPDATE better_together_geography_regions
      SET state_id = #{NL}, country_id = (SELECT country_id FROM better_together_geography_states WHERE iso_code = 'CA-NL')
      WHERE type = 'NewfoundlandLabradorOnline::ProvincialElectoralDistrict' AND state_id IS NULL
    SQL
  end

  def swap_unique_indexes
    remove_index :political_parties, name: OLD_PARTY_INDEX, if_exists: true
    remove_index :elections, name: OLD_ELECTION_INDEX, if_exists: true
    add_index :political_parties, %i[jurisdiction state_id identifier], unique: true, nulls_not_distinct: true,
                                                                        name: PARTY_INDEX, if_not_exists: true
    add_index :elections, %i[jurisdiction state_id held_on], unique: true, nulls_not_distinct: true,
                                                             name: ELECTION_INDEX, if_not_exists: true
  end
end
