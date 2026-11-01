# frozen_string_literal: true

require 'rails_helper'

RSpec.describe NewfoundlandLabradorOnline::SettlementIdentifier do
  include RequestSpecHelper

  before { configure_host_platform }

  let(:settlement) { create(:geography_settlement) }

  it 'keeps values unique per scheme and rejects unknown schemes', :aggregate_failures do
    settlement.identifiers.create!(scheme: 'statcan_csd', value: '1005018')

    expect(create(:geography_settlement).identifiers.build(scheme: 'statcan_csd', value: '1005018')).not_to be_valid
    expect(settlement.identifiers.build(scheme: 'nope', value: 'x')).not_to be_valid
  end

  it 'finds a settlement by identifier', :aggregate_failures do
    settlement.identifiers.create!(scheme: 'statcan_csd', value: '1005018')

    expect(BetterTogether::Geography::Settlement.with_identifier('statcan_csd', '1005018')).to eq(settlement)
    expect(settlement.identifier_for('statcan_csd')).to eq('1005018')
  end

  it 'allows one identifier per scheme on a settlement' do
    settlement.identifiers.create!(scheme: 'wikidata', value: 'Q1')

    expect(settlement.identifiers.build(scheme: 'wikidata', value: 'Q2')).not_to be_valid
  end
end
