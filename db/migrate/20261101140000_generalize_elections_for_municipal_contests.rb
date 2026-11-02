# frozen_string_literal: true

# Lets a council election fit the electoral tables: an election can belong to a body (a council), a contest can be for
# an office rather than a district, can elect several people, and can sit on a ward seat; a candidacy can have no party
# and can be acclaimed. Additive and guarded; provincial rows are unchanged.
class GeneralizeElectionsForMunicipalContests < ActiveRecord::Migration[8.1]
  def up
    generalize_elections
    generalize_contests
    generalize_candidacies
  end

  def down
    remove_column :candidacies, :acclaimed if column_exists?(:candidacies, :acclaimed)
    remove_index :electoral_contests, name: 'index_electoral_contests_on_municipal_office', if_exists: true
    %i[community_seat_id seats_available office].each do |column|
      remove_column :electoral_contests, column if column_exists?(:electoral_contests, column)
    end
    swap_election_index(%i[jurisdiction state_id held_on], 'index_elections_on_jurisdiction_state_held_on')
    remove_column :elections, :kind if column_exists?(:elections, :kind)
    remove_reference :elections, :community, type: :uuid, foreign_key: { to_table: :better_together_communities } if
      column_exists?(:elections, :community_id)
  end

  private

  def generalize_elections
    unless column_exists?(:elections, :community_id)
      add_reference :elections, :community, type: :uuid, null: true,
                                            foreign_key: { to_table: :better_together_communities }
    end
    add_column :elections, :kind, :string, limit: 30, default: 'general', null: false unless
      column_exists?(:elections, :kind)
    swap_election_index(%i[jurisdiction state_id community_id held_on], 'index_elections_on_body_and_held_on')
  end

  def swap_election_index(columns, name)
    remove_index :elections, name: 'index_elections_on_jurisdiction_state_held_on', if_exists: true
    remove_index :elections, name: 'index_elections_on_body_and_held_on', if_exists: true
    add_index :elections, columns, unique: true, nulls_not_distinct: true, name:
  end

  def generalize_contests # rubocop:disable Metrics/MethodLength
    change_column_null :electoral_contests, :region_id, true
    add_column :electoral_contests, :office, :string, limit: 30, default: 'member', null: false unless
      column_exists?(:electoral_contests, :office)
    add_column :electoral_contests, :seats_available, :integer, default: 1, null: false unless
      column_exists?(:electoral_contests, :seats_available)
    unless column_exists?(:electoral_contests, :community_seat_id)
      add_reference :electoral_contests, :community_seat, type: :uuid, null: true, foreign_key: true
    end
    add_index :electoral_contests, %i[election_id office community_seat_id],
              unique: true, nulls_not_distinct: true, where: 'region_id IS NULL',
              name: 'index_electoral_contests_on_municipal_office', if_not_exists: true
  end

  def generalize_candidacies
    change_column_null :candidacies, :party_name, true
    change_column_null :candidacies, :votes, true
    add_column :candidacies, :acclaimed, :boolean, default: false, null: false unless
      column_exists?(:candidacies, :acclaimed)
  end
end
