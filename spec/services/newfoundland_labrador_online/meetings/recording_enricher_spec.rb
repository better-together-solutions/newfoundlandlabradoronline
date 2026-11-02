# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable RSpec/ExampleLength, RSpec/MultipleExpectations

RSpec.describe NewfoundlandLabradorOnline::Meetings::RecordingEnricher do
  include RequestSpecHelper

  let(:meeting) { NewfoundlandLabradorOnline::Meeting.find_by!(source_id: '11111111-aaaa-4aaa-8aaa-000000000001') }
  let(:recording) { meeting.recordings.sole }
  let(:vtt) { Rails.root.join('spec/fixtures/meetings/youtube_auto.vtt').read }
  let(:metadata) do
    { 'abc123xyz00' => { 'live_status' => 'was_live', 'duration' => 1740, 'timestamp' => 1_793_042_723,
                         'release_timestamp' => 1_793_040_000,
                         'captions' => { 'en' => { 'source' => 'youtube_auto', 'vtt' => vtt } } } }
  end

  before do
    configure_host_platform
    corner_brook_council
    import_meetings
  end

  def enrich(apply: true, data: metadata) = described_class.new(metadata: data, apply:).call

  it 'creates the recording from the source link with the privacy embed', :aggregate_failures do
    expect(recording).to have_attributes(provider: 'youtube', provider_ref: 'abc123xyz00', match_method: 'source_link',
                                         live_status: 'past',
                                         embed_url: 'https://www.youtube-nocookie.com/embed/abc123xyz00')
  end

  it 'writes nothing unless applying, but reports what it would do', :aggregate_failures do
    result = enrich(apply: false)

    expect(result.counts).to eq(updated: 1, captions: 0, unmatched: 0)
    expect(NewfoundlandLabradorOnline::RecordingCaption.count).to eq(0)
  end

  it 'stores the schedule, length and captions as cues', :aggregate_failures do
    result = enrich
    caption = recording.reload.caption

    expect(result.counts).to eq(updated: 1, captions: 1, unmatched: 0)
    expect(recording).to have_attributes(duration_seconds: 1740, live_status: 'past')
    expect(recording.published_at.to_i).to eq(1_793_042_723)
    expect(caption).to have_attributes(language: 'en', source: 'youtube_auto')
    expect(caption.automatic?).to be(true)
    expect(caption.cues.size).to eq(4)
    expect(caption.body).to include('Call the meeting to order.')
  end

  it 'sets the event length to the recording length rounded up to 5 minutes' do
    enrich

    expect(meeting.event.reload.duration_minutes).to eq(30)
  end

  it 'leaves unchanged captions alone on a second run' do
    enrich

    expect(enrich.counts).to include(captions: 0)
  end

  it 'marks upcoming and live streams, without captions' do
    enrich(data: { 'abc123xyz00' => { 'live_status' => 'is_upcoming', 'release_timestamp' => 1_793_040_000 } })

    expect(recording.reload).to have_attributes(live_status: 'upcoming')
    expect(meeting.event.reload.duration_minutes).to eq(120)
  end

  it 'reports videos with no recording' do
    expect(enrich(data: { 'zzzzzzzzzzz' => {} }).unmatched).to eq(['zzzzzzzzzzz'])
  end

  it 'keeps a hand matched recording when the import runs again' do
    recording.update!(match_method: 'manual', watch_url: 'https://www.youtube.com/watch?v=abc123xyz00&t=5')
    import_meetings(meetings: fixture_meetings.map { |m| m.merge(location: "#{m[:location]} ") })

    expect(recording.reload.watch_url).to end_with('&t=5')
  end
end
# rubocop:enable RSpec/ExampleLength, RSpec/MultipleExpectations
