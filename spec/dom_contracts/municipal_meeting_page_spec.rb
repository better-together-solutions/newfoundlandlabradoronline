# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable RSpec/ExampleLength, RSpec/MultipleExpectations
# Stable identifiers for one council meeting's page: recording, documents and the transcript.
RSpec.describe 'Municipal meeting page', type: :request do
  include RequestSpecHelper

  let(:locale) { I18n.default_locale }
  let(:meeting) { NewfoundlandLabradorOnline::Meeting.find_by!(source_id: '11111111-aaaa-4aaa-8aaa-000000000001') }
  let(:vtt) { Rails.root.join('spec/fixtures/meetings/youtube_auto.vtt').read }
  let(:path) { "/#{locale}/e/municipalities/nl/corner-brook/meetings/#{meeting.id}" }

  before do
    configure_host_platform.update!(privacy: 'public')
    corner_brook_council
    import_meetings
  end

  def enrich(status: 'was_live')
    NewfoundlandLabradorOnline::Meetings::RecordingEnricher.new(
      metadata: { 'abc123xyz00' => { 'live_status' => status, 'duration' => 1740,
                                     'captions' => { 'en' => { 'source' => 'youtube_auto', 'vtt' => vtt } } } },
      apply: true
    ).call
  end

  it 'shows the privacy embed, documents and a collapsed automatic transcript', :aggregate_failures do
    enrich
    get path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('id="municipality-meeting-page"', 'id="meeting-title"', 'id="meeting-video"',
                                     'https://www.youtube-nocookie.com/embed/abc123xyz00', 'id="meeting-watch-link"',
                                     'id="meeting-documents"', 'id="meeting-transcript-details"',
                                     'id="meeting-transcript-notice"', 'id="meeting-cues"',
                                     'id="meeting-transcript-download"')
    expect(response.body).not_to match(/<details[^>]*\sopen/)
    expect(response.body.scan('class="meeting-cue"').size).to eq(4)
  end

  it 'offers the schedule and a watch live link instead of the player for an upcoming stream', :aggregate_failures do
    enrich(status: 'is_upcoming')
    get path

    expect(response.body).to include('id="meeting-recording-upcoming"', 'id="meeting-watch-live"')
    expect(response.body).not_to include('id="meeting-video"')
  end

  it 'has no transcript section without captions' do
    get path

    expect(response.body).to include('id="meeting-video"')
    expect(response.body).not_to include('id="meeting-transcript"')
  end

  it 'downloads the transcript as text with start times', :aggregate_failures do
    enrich
    get "#{path}/transcript"

    expect(response).to have_http_status(:ok)
    expect(response.headers['Content-Disposition']).to include('attachment')
    expect(response.body).to start_with('[00:00:02] >> Mhm.')
  end

  it 'answers 404 for the transcript of a meeting without captions' do
    get "#{path}/transcript"

    expect(response).to have_http_status(:not_found)
  end

  it 'links the timeline row to the meeting page when it has a recording' do
    get "/#{locale}/e/municipalities/nl/corner-brook/meetings"

    expect(response.body).to include('meeting-details-link', path)
  end
end
# rubocop:enable RSpec/ExampleLength, RSpec/MultipleExpectations
