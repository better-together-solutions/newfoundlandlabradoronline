# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # The area a seat (a ward) represents, with the authority and download page it came from.
  class SeatBoundary < BetterTogether::ApplicationRecord
    self.table_name = 'seat_boundaries'

    belongs_to :community_seat, class_name: 'NewfoundlandLabradorOnline::CommunitySeat', inverse_of: :boundary_record

    validates :authority, presence: true
    validates :community_seat_id, uniqueness: true

    # Sets the boundary from a GeoJSON geometry (hash or string), repaired to a valid multi polygon.
    def assign_boundary_from_geojson!(geometry)
      json = geometry.is_a?(String) ? geometry : geometry.to_json
      sql = self.class.sanitize_sql_array(
        ['UPDATE seat_boundaries SET boundary = ' \
         'ST_Multi(ST_CollectionExtract(ST_MakeValid(ST_GeomFromGeoJSON(?)), 3))::geography WHERE id = ?', json, id]
      )
      self.class.connection.execute(sql)
      self.class.where(id:).update_all('area_km2 = ST_Area(boundary) / 1000000.0')
      reload
    end
  end
end
