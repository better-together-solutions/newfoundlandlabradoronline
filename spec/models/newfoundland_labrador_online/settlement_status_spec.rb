# frozen_string_literal: true

require 'rails_helper'

RSpec.describe NewfoundlandLabradorOnline::SettlementStatus do
  include RequestSpecHelper

  before { configure_host_platform }

  let(:settlement) { create(:geography_settlement) }

  def status(attrs = {})
    described_class.create!({ settlement:, municipal_status: 'local_service_district', valid_from: '1950-01-01',
                              valid_to: '1999-12-31', authority: 'Test' }.merge(attrs))
  end

  it 'resolves the status in force on a date', :aggregate_failures do
    old = status
    current = status(municipal_status: 'town', valid_from: '2000-01-01', valid_to: nil)

    expect(settlement.status_on(Date.new(1980, 6, 1))).to eq(old)
    expect(settlement.current_status).to eq(current)
    expect(current).to be_incorporated
  end

  it 'treats a status with no dates as always in force' do
    open_ended = status(valid_from: nil, valid_to: nil)

    expect(settlement.status_on(Date.new(2001, 1, 1))).to eq(open_ended)
  end

  it 'rejects an unknown status and a reversed range', :aggregate_failures do
    expect(described_class.new(settlement:, municipal_status: 'village', authority: 'Test')).not_to be_valid
    expect(described_class.new(settlement:, municipal_status: 'town', valid_from: '2020-01-01',
                               valid_to: '2019-01-01', authority: 'Test')).not_to be_valid
  end
end
