# frozen_string_literal: true

# Data layers that need a credit wherever they are drawn on a CE map. Maps offer them through Map#layers and the
# shared map partial adds the credit to Leaflet's attribution control while the data is on the map. Each credit is
# one short link (source and licence together); the full authority and licence are on the page.
Rails.application.config.to_prepare do
  BetterTogether::Geography::MapLayer.register(
    :nl_electoral_boundaries,
    label: 'Electoral district boundaries',
    attribution: 'NL Electoral Boundaries Commission (OGL-NL)',
    attribution_url: 'https://opendata.gov.nl.ca/public/opendata/page/?page-id=datasetdetails&id=361'
  )
end
