# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # One boundary and name a region had over a date range (a region keeps one identity across redistributions).
  class RegionVersion < BetterTogether::ApplicationRecord
    self.table_name = 'nlo_region_versions'

    belongs_to :region, class_name: 'BetterTogether::Geography::Region', inverse_of: :versions

    validates :name, :valid_from, :authority, presence: true
    validate :valid_to_after_valid_from

    scope :on, lambda { |date|
      where(valid_from: ..date).where('valid_to IS NULL OR valid_to >= ?', date)
    }
    scope :current, -> { on(Time.zone.today) }
    scope :chronological, -> { order(:valid_from) }

    # Sets the boundary from a GeoJSON geometry (hash or string), repaired to a valid multi polygon.
    def assign_boundary_from_geojson!(geometry)
      json = geometry.is_a?(String) ? geometry : geometry.to_json
      sql = self.class.sanitize_sql_array(
        ['UPDATE nlo_region_versions SET boundary = ' \
         'ST_Multi(ST_CollectionExtract(ST_MakeValid(ST_GeomFromGeoJSON(?)), 3))::geography WHERE id = ?', json, id]
      )
      self.class.connection.execute(sql)
      reload
    end

    # Square kilometres, computed in PostGIS; nil when there is no boundary.
    def area_km2
      return unless boundary

      self.class.where(id:).pick(Arel.sql('ST_Area(boundary) / 1000000.0'))
    end

    private

    def valid_to_after_valid_from
      return if valid_to.blank? || valid_from.blank? || valid_to >= valid_from

      errors.add(:valid_to, :invalid)
    end
  end
end
