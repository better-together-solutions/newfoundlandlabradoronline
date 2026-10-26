# frozen_string_literal: true

# Links between communities: hierarchy (committee of a legislature), peer (coalition) and membership (a co-op in a
# federation), each with a participation mode that says who may join the target community.
class CreateCommunityAssociations < ActiveRecord::Migration[8.1]
  CHECK = 'community_association_not_self'

  def up # rubocop:disable Metrics/MethodLength
    return if table_exists?(:community_associations)

    create_table :community_associations, id: :uuid do |t|
      t.integer :lock_version, default: 0, null: false
      t.timestamps
      t.references :source_community, type: :uuid, null: false, index: true,
                                      foreign_key: { to_table: :better_together_communities }
      t.references :target_community, type: :uuid, null: false, index: true,
                                      foreign_key: { to_table: :better_together_communities }
      t.string :relation, null: false, limit: 50
      t.string :kind, null: false, limit: 30
      t.string :role, limit: 30
      t.string :participation, null: false, limit: 30
      t.string :eligibility_group, limit: 50
      t.boolean :cascade_end, null: false, default: false
      t.date :starts_on
      t.date :ends_on
      t.index %i[source_community_id target_community_id relation starts_on], unique: true, nulls_not_distinct: true,
                                                                              name: 'index_community_associations_uniq'
      t.check_constraint 'source_community_id <> target_community_id', name: CHECK
    end
  end

  def down
    drop_table :community_associations, if_exists: true
  end
end
