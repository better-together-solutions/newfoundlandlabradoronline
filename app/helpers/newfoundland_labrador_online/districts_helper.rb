# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # The outline map for a district page.
  module DistrictsHelper
    def district_map(district)
      NewfoundlandLabradorOnline::DistrictMap.find_or_initialize_by(identifier: "district-#{district.identifier}")
                                             .tap { |map| map.district = district }
    end
  end
end
