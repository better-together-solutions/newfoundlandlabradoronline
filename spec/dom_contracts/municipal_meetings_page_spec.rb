# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable RSpec/ExampleLength
# Stable identifiers for the council meetings tab of a municipality page and for the council host chip.
RSpec.describe 'Municipal meetings page', type: :request do
  include RequestSpecHelper

  let(:locale) { I18n.default_locale }
  let(:meeting) { NewfoundlandLabradorOnline::Meeting.find_by!(source_id: '11111111-aaaa-4aaa-8aaa-000000000001') }

  before do
    configure_host_platform.update!(privacy: 'public')
    corner_brook_council
    import_meetings
  end

  it 'lists one timeline with a toggle per meeting type, all on', :aggregate_failures do
    get "/#{locale}/e/municipalities/nl/corner-brook/meetings"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('id="municipality-meetings-page"', 'id="municipality-tabs"',
                                     'id="council-meetings"',
                                     'id="meeting-filters"', 'id="meetings-timeline"', 'id="meetings-source"',
                                     "id=\"#{ActionView::RecordIdentifier.dom_id(meeting)}\"")
    expect(response.body.scan('aria-pressed="true"').size).to eq(2)
    expect(response.body).not_to include('aria-pressed="false"')
    expect(response.body).to include('id="meeting-filter-meeting-regular"',
                                     'id="meeting-filter-meeting-committee_of_the_whole"')
  end

  it 'links documents out to the portal and marks cancelled meetings', :aggregate_failures do
    get "/#{locale}/e/municipalities/nl/corner-brook/meetings"

    expect(response.body).to include('https://pub-example.escribemeetings.com/FileStream.ashx?DocumentId=103',
                                     'meeting-cancelled')
    expect(response.body).not_to include('/rails/active_storage')
  end

  it 'shows the meetings tab on the municipality overview' do
    get "/#{locale}/e/municipalities/nl/corner-brook"

    expect(response.body).to include('id="municipality-tab-overview"', 'id="municipality-tab-meetings"')
  end

  it 'links the council host chip on event lists to the municipality page, not the community page',
     :aggregate_failures do
    get better_together.events_path(locale:)

    links = Nokogiri::HTML(response.body).css('.event-host a').pluck('href')
    expect(links).to all(eq("/#{locale}/e/municipalities/nl/corner-brook"))
    expect(links).not_to be_empty
  end

  it 'shows the municipality card, linked to the municipality page, as host on the event page', :aggregate_failures do
    get better_together.event_path(meeting.event, locale:)

    hosts_id = ActionView::RecordIdentifier.dom_id(meeting.event, :event_hosts)
    card = Nokogiri::HTML(response.body).at_css("##{hosts_id} .municipality-host-card")
    expect(card).to be_present
    expect(card.at_css('a')['href']).to eq("/#{locale}/e/municipalities/nl/corner-brook")
  end
end
# rubocop:enable RSpec/ExampleLength
