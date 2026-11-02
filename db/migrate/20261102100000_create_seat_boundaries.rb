# frozen_string_literal: true

# The area a ward seat represents, with the authority and download page that say so. One current boundary per seat.
class CreateSeatBoundaries < ActiveRecord::Migration[8.1]
  def up # rubocop:disable Metrics/MethodLength
    return if table_exists?(:seat_boundaries)

    create_table :seat_boundaries, id: :uuid do |t|
      t.integer :lock_version, default: 0, null: false
      t.references :community_seat, type: :uuid, null: false, index: { unique: true }, foreign_key: true
      t.geography :boundary, limit: { srid: 4326, type: 'multi_polygon', geographic: true }
      t.string :authority, null: false
      t.string :source_url
      t.string :portal_url
      t.string :license
      t.string :source_sha256, limit: 64
      t.date :fetched_on
      t.decimal :area_km2, precision: 12, scale: 2
      t.timestamps
    end
    add_index :seat_boundaries, :boundary, using: :gist
  end

  def down
    drop_table :seat_boundaries if table_exists?(:seat_boundaries)
  end
end
