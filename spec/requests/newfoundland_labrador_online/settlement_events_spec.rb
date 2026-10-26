# frozen_string_literal: true

require 'rails_helper'

# The settlement page Events tab embeds the events index scoped to the settlement (/events?settlement=), so it has
# the index's cards and filters. The set is Event.located_in through the events policy scope.
RSpec.describe 'Settlement events' do
  include RequestSpecHelper

  let(:locale) { I18n.default_locale }
  let(:platform) { BetterTogether::Platform.find_by(host: true) }
  let(:settlement) { create(:geography_settlement, identifier: 'cb-town', name: 'Cbtown') }

  def make_event(name, **attrs)
    create(:better_together_event, platform:, name:, privacy: 'public', status: 'confirmed', **attrs)
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

  it 'embeds the events index for the settlement in the Events tab', :aggregate_failures do
    get "/#{locale}/g/settlements/#{settlement.slug}"

    expect(response.body).to include('id="events-tab"', 'id="settlement-events"',
                                     "/#{locale}/events?settlement=cb-town")
  end

  describe 'GET /events?settlement=' do
    it 'lists only upcoming public events located at the settlement, with the index filters', :aggregate_failures do
      get "/#{locale}/events", params: { settlement: 'cb-town' }

      expect(response.body).to include('turbo-frame', 'Here soon', 'events-filter-sidebar', 'events-past')
      expect(response.body).not_to include('Here but past', 'Hidden private', 'Elsewhere')
    end

    it 'lists the past events of the settlement when asked', :aggregate_failures do
      get "/#{locale}/events", params: { settlement: 'cb-town', past: '1' }

      expect(response.body).to include('Here but past')
      expect(response.body).not_to include('Here soon', 'Elsewhere')
    end

    it 'keeps the settlement scope in the filter form', :aggregate_failures do
      get "/#{locale}/events", params: { settlement: 'cb-town' }, headers: { 'Turbo-Frame' => 'settlement-events' }

      expect(response.body).to include('name="settlement"', 'data-turbo-frame="settlement-events"')
    end

    it 'leaves the plain events index unscoped', :aggregate_failures do
      get "/#{locale}/events"

      expect(response.body).to include('Here soon', 'Elsewhere')
      expect(response.body).not_to include('settlement-events')
    end
  end
end
