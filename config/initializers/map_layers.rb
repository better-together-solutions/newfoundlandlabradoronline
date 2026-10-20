# frozen_string_literal: true

# Data layers that need a credit wherever they are drawn on a CE map. Maps offer them through Map#layers and the
# shared map partial adds the credit to Leaflet's attribution control while the data is on the map.
Rails.application.config.to_prepare do
  BetterTogether::Geography::MapLayer.register(
    :nl_electoral_boundaries,
    label: 'Electoral district boundaries',
    attribution: 'Newfoundland and Labrador Electoral Boundaries Commission',
    attribution_url: 'https://opendata.gov.nl.ca/public/opendata/page/?page-id=datasetdetails&id=361',
    licence: 'Open Government Licence - Newfoundland and Labrador'
  )
end
