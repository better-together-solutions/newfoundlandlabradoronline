# frozen_string_literal: true

require 'rails_helper'

# An event located at a street address reaches the settlement's events list once CE places the address in the
# settlement (HierarchyResolutionJob, polygon containment). Nothing here sets the settlement on the event.
RSpec.describe 'Address located events on the settlement page' do
  include RequestSpecHelper

  let(:locale) { I18n.default_locale }
  let(:lat) { 48.9517 }
  let(:lng) { -57.9474 }
  let(:settlement) { create(:geography_settlement, identifier: 'cb-town', name: 'Cbtown') }
  let(:address_json) do
    { line1: '5 Park Street', city_name: 'Corner Brook', postal_code: 'A2H 2W9', country_name: 'Canada' }.to_json
  end

  def square(center_lng:, center_lat:, radius: 0.1)
    factory = RGeo::Geographic.spherical_factory(srid: 4326)
    ring = [[-1, -1], [1, -1], [1, 1], [-1, 1], [-1, -1]].map do |x, y|
      factory.point(center_lng + (x * radius), center_lat + (y * radius))
    end
    factory.polygon(factory.linear_ring(ring))
  end

  before do
    configure_host_platform
    settlement.space.boundary = square(center_lng: lng, center_lat: lat)
    settlement.save!
    event = create(:better_together_event, name: 'At the Arts Centre', privacy: 'public',
                                           starts_at: 3.days.from_now, ends_at: 3.days.from_now + 2.hours)
    event.update!(address_spec: address_json)
    address = event.location.location
    address.space.update!(latitude: lat, longitude: lng)
    BetterTogether::Geography::HierarchyResolutionJob.perform_now(address)
  end

  it 'lists the event under the settlement it sits in' do
    get "/#{locale}/g/settlements/#{settlement.slug}"

    expect(response.body).to include('At the Arts Centre')
  end
end
