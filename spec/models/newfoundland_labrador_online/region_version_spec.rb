# frozen_string_literal: true

require 'rails_helper'

RSpec.describe NewfoundlandLabradorOnline::RegionVersion do
  include RequestSpecHelper

  before { configure_host_platform }

  let(:region) { create(:geography_region) }

  def version(attrs = {})
    described_class.create!({ region:, name: 'Old', valid_from: '2007-01-01', valid_to: '2015-11-29',
                              authority: 'Test' }.merge(attrs))
  end

  it 'resolves the version in force on a date', :aggregate_failures do
    old = version
    current = version(name: 'New', valid_from: '2015-11-30', valid_to: nil)

    expect(region.version_on(Date.new(2011, 10, 11))).to eq(old)
    expect(region.version_on(Date.new(2025, 10, 14))).to eq(current)
    expect(region.current_version).to eq(current)
  end

  it 'rejects a valid_to before valid_from' do
    expect(described_class.new(region:, name: 'X', valid_from: '2020-01-01', valid_to: '2019-01-01',
                               authority: 'Test')).not_to be_valid
  end

  it 'keeps identifiers unique per scheme and value', :aggregate_failures do
    region.identifiers.create!(scheme: 'wikidata', value: 'Q1')
    other = create(:geography_region)

    expect(other.identifiers.build(scheme: 'wikidata', value: 'Q1')).not_to be_valid
    expect(region.identifiers.build(scheme: 'nope', value: 'x')).not_to be_valid
    expect(BetterTogether::Geography::Region.with_identifier('wikidata', 'Q1')).to eq(region)
  end
end
