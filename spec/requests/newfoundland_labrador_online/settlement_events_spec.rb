# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Settlement events' do
  include RequestSpecHelper

  let(:locale) { I18n.default_locale }
  let(:platform) { BetterTogether::Platform.find_by(host: true) }
  let(:settlement) { create(:geography_settlement, identifier: 'cb-town', name: 'Cbtown') }

  def make_event(name, **attrs)
    create(:better_together_event, platform:, name:, privacy: 'public', **attrs)
  end

  before do
    configure_host_platform
    settlement
    make_event('Here soon', starts_at: 3.days.from_now, ends_at: 3.days.from_now + 2.hours)
      .update!(settlement_identifier: 'cb-town')
    make_event('Here but past', starts_at: 3.days.ago, ends_at: 3.days.ago + 2.hours)
      .update!(settlement_identifier: 'cb-town')
    make_event('Hidden private', starts_at: 4.days.from_now, ends_at: 4.days.from_now + 2.hours, privacy: 'private')
      .update!(settlement_identifier: 'cb-town')
    make_event('Elsewhere', starts_at: 5.days.from_now, ends_at: 5.days.from_now + 2.hours)
  end

  it 'lists only upcoming public events located at the settlement', :aggregate_failures do
    get "/#{locale}/g/settlements/#{settlement.slug}"

    expect(response.body).to include('id="events-tab"', 'Here soon')
    expect(response.body).not_to include('Here but past', 'Hidden private', 'Elsewhere')
  end

  it 'says so when there are no upcoming events' do
    other = create(:geography_settlement, identifier: 'quiet-town', name: 'Quiet Town')

    get "/#{locale}/g/settlements/#{other.slug}"

    expect(response.body).to include('No upcoming events in Quiet Town yet.')
  end
end
