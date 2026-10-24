# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # A community's map (CE's, from its building connections) also shows the place the community is located at, when
  # that place has coordinates and the community has no building pins of its own. CE's event page renders its map the
  # same way: the record's own map on the shared map partial.
  module LocatedMapPoints
    def leaflet_points
      points = super
      points.presence || located_leaflet_point
    end

    def spaces
      own = super
      own.presence || [location&.location&.space].compact.select(&:geocoded?)
    end
  end
end
