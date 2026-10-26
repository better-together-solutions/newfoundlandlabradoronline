# frozen_string_literal: true

# Stores each version's area so listing pages do not recompute it in PostGIS from the full-resolution boundary.
class AddAreaKm2ToRegionVersions < ActiveRecord::Migration[8.1]
  def up
    unless column_exists?(:region_versions, :area_km2)
      add_column :region_versions, :area_km2, :decimal, precision: 12, scale: 2
    end
    execute 'UPDATE region_versions SET area_km2 = ST_Area(boundary) / 1000000.0 WHERE boundary IS NOT NULL'
  end

  def down
    remove_column :region_versions, :area_km2 if column_exists?(:region_versions, :area_km2)
  end
end
