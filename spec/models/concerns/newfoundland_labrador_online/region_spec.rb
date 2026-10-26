# frozen_string_literal: true

require 'rails_helper'

RSpec.describe NewfoundlandLabradorOnline::Region do
  include RequestSpecHelper

  before { configure_host_platform }

  it 'keeps a district primary community private', :aggregate_failures do
    path = Rails.root.join('spec/fixtures/nl_regions/two_districts.geojson')
    NewfoundlandLabradorOnline::Geography::ProvincialDistrictLoader.new(path:).call

    communities = NewfoundlandLabradorOnline::ProvincialElectoralDistrict.all.map(&:community)
    expect(communities).not_to be_empty
    expect(communities.map(&:privacy).uniq).to eq(['private'])
  end
end
