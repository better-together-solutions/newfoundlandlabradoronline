# frozen_string_literal: true

# Host-side first cut of versioned region boundaries and external identifiers.
class CreateRegionVersionsAndIdentifiers < ActiveRecord::Migration[8.1]
  def change
    create_region_versions unless table_exists?(:region_versions)
    create_region_identifiers unless table_exists?(:region_identifiers)
  end

  private

  def create_region_versions # rubocop:disable Metrics/MethodLength
    create_table :region_versions, id: :uuid do |t|
      t.integer :lock_version, default: 0, null: false
      t.timestamps
      t.references :region, type: :uuid, null: false, index: false,
                            foreign_key: { to_table: :better_together_geography_regions }
      t.string :name, null: false
      t.date :valid_from, null: false
      t.date :valid_to
      t.geography :boundary, limit: { srid: 4326, type: 'multi_polygon', geographic: true }
      t.string :authority, null: false
      t.string :source_url
      t.string :source_sha256, limit: 64
      t.string :license
      t.index %i[region_id valid_from], unique: true, name: 'index_region_versions_on_region_and_valid_from'
      t.index :boundary, using: :gist
    end
  end

  def create_region_identifiers
    create_table :region_identifiers, id: :uuid do |t|
      t.integer :lock_version, default: 0, null: false
      t.timestamps
      t.references :region, type: :uuid, null: false, index: true,
                            foreign_key: { to_table: :better_together_geography_regions }
      t.string :scheme, null: false, limit: 50
      t.string :value, null: false
      t.index %i[scheme value], unique: true, name: 'index_region_identifiers_on_scheme_and_value'
      t.index %i[region_id scheme], unique: true, name: 'index_region_identifiers_on_region_and_scheme'
    end
  end
end
