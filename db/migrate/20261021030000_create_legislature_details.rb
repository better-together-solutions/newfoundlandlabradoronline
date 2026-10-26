# frozen_string_literal: true

# Attributes of a legislature community (level, jurisdiction, size); the community itself is a subtype of Community.
class CreateLegislatureDetails < ActiveRecord::Migration[8.1]
  def up # rubocop:disable Metrics/MethodLength
    return if table_exists?(:legislature_details)

    create_table :legislature_details, id: :uuid do |t|
      t.integer :lock_version, default: 0, null: false
      t.timestamps
      t.references :community, type: :uuid, null: false, index: { unique: true },
                               foreign_key: { to_table: :better_together_communities }
      t.string :level, null: false, limit: 30
      t.string :jurisdiction_type
      t.uuid :jurisdiction_id
      t.integer :seat_count
      t.string :member_title
      t.index %i[jurisdiction_type jurisdiction_id], name: 'index_legislature_details_on_jurisdiction'
    end
  end

  def down
    drop_table :legislature_details, if_exists: true
  end
end
