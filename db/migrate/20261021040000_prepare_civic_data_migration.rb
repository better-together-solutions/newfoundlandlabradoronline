# frozen_string_literal: true

# Columns the move from elected terms and party memberships to the civic model needs: a party's community, the reason
# and source a party membership started with, and one mandate per candidacy.
class PrepareCivicDataMigration < ActiveRecord::Migration[8.1]
  CANDIDACY_INDEX = 'index_membership_mandates_on_candidacy'

  def up
    unless column_exists?(:political_parties, :community_id)
      add_reference :political_parties, :community, type: :uuid, null: true, index: { unique: true },
                                                    foreign_key: { to_table: :better_together_communities }
    end
    add_column :membership_mandates, :source_url, :string unless column_exists?(:membership_mandates, :source_url)
    add_column :membership_mandates, :start_reason, :string, limit: 50 unless column_exists?(:membership_mandates,
                                                                                             :start_reason)
    add_candidacy_index
  end

  def down
    remove_index :membership_mandates, name: CANDIDACY_INDEX if index_name_exists?(:membership_mandates,
                                                                                   CANDIDACY_INDEX)
    remove_column :membership_mandates, :start_reason if column_exists?(:membership_mandates, :start_reason)
    remove_column :membership_mandates, :source_url if column_exists?(:membership_mandates, :source_url)
    if column_exists?(
      :political_parties, :community_id
    )
      remove_reference :political_parties, :community,
                       foreign_key: { to_table: :better_together_communities }
    end
  end

  private

  def add_candidacy_index
    return if index_name_exists?(:membership_mandates, CANDIDACY_INDEX)

    add_index :membership_mandates, %i[conferred_by_type conferred_by_id], unique: true, name: CANDIDACY_INDEX,
                                                                           where: 'conferred_by_id IS NOT NULL'
  end
end
