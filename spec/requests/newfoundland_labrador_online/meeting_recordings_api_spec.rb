# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable RSpec/ExampleLength, RSpec/MultipleExpectations, RSpec/MultipleMemoizedHelpers
# POST /api/v1/meeting_recordings, used by the management tool's meeting recording sync.
RSpec.describe 'Meeting recordings API', type: :request do
  include RequestSpecHelper

  let(:path) { '/api/v1/meeting_recordings' }
  let(:vtt) { Rails.root.join('spec/fixtures/meetings/youtube_auto.vtt').read }
  let(:manager) { BetterTogether::User.find_by!(email: 'manager@example.test') }
  let(:headers) { api_auth_headers(manager, content_type: 'application/json') }
  let(:no_video_source_id) { '11111111-aaaa-4aaa-8aaa-000000000003' }
  let(:metadata) do
    { 'live_status' => 'was_live', 'duration' => 3000, 'timestamp' => 1_789_000_000,
      'captions' => { 'en' => { 'source' => 'youtube_auto', 'vtt' => vtt } } }
  end
  let(:accept_agreement) { true }
  let(:body) { { video_id: 'zzz111yyy22', source_id: no_video_source_id, metadata: } }
  let(:meeting) { NewfoundlandLabradorOnline::Meeting.find_by!(source_id: no_video_source_id) }

  before do
    configure_host_platform
    corner_brook_council
    import_meetings
    accept_publishing_agreement if accept_agreement
  end

  def accept_publishing_agreement
    BetterTogether::AgreementBuilder.build
    BetterTogether::Agreement.find_by!(identifier: 'content_publishing_agreement').agreement_participants
                             .create!(participant: manager.person, accepted_at: Time.zone.now,
                                      acceptance_method: 'system')
  end

  def post_recording(params = body, request_headers = headers)
    post path, params: params.to_json, headers: request_headers
  end

  def json = JSON.parse(response.body)

  def recording_count = NewfoundlandLabradorOnline::MeetingRecording.count

  it 'attaches the video, its captions and a public video block', :aggregate_failures do
    post_recording

    expect(response).to have_http_status(:created)
    expect(json).to include('status' => 'attached', 'captions' => 1, 'dry_run' => false)
    recording = meeting.recordings.sole
    expect(recording).to have_attributes(provider_ref: 'zzz111yyy22', match_method: 'date_match', live_status: 'past')
    expect(recording.caption.body).to include('Call the meeting to order.')
    block = BetterTogether::Content::VideoBlock.find(meeting.reload.details['video_block_id'])
    expect(block).to have_attributes(video_url: 'https://www.youtube.com/watch?v=zzz111yyy22')
    expect(meeting.event.reload.description.body.attachables).to include(block)
  end

  it 'is idempotent', :aggregate_failures do
    post_recording
    expect { post_recording }.not_to(change { [recording_count, NewfoundlandLabradorOnline::RecordingCaption.count] })

    expect(json).to include('status' => 'unchanged', 'captions' => 0)
    expect(response).to have_http_status(:ok)
  end

  it 'writes nothing on a dry run', :aggregate_failures do
    post_recording(body.merge(dry_run: true))

    expect(json).to include('status' => 'would_attach', 'dry_run' => true)
    expect(meeting.recordings).to be_empty
  end

  it 'finds the meeting by local date and body', :aggregate_failures do
    post_recording(body.except(:source_id).merge(date: '2026-09-14', body_key: meeting.body_key))

    expect(json).to include('status' => 'attached', 'source_id' => no_video_source_id)
  end

  it 'uses the St. John\'s date, not UTC, for a late evening meeting' do
    post_recording(body.except(:source_id).merge(date: '2026-10-26', video_id: 'abc123xyz00', dry_run: true))

    expect(json['source_id']).to eq('11111111-aaaa-4aaa-8aaa-000000000001')
  end

  it 'refuses a date with no meeting' do
    post_recording(body.except(:source_id).merge(date: '2001-01-01'))

    expect(response).to have_http_status(:not_found)
    expect(json['error']).to eq('meeting_not_found')
  end

  it 'refuses a meeting that already has a different recording', :aggregate_failures do
    post_recording
    post_recording(body.merge(video_id: 'qqq333rrr44'))

    expect(response).to have_http_status(:conflict)
    expect(json['error']).to eq('meeting_has_other_recording')
  end

  it 'refuses a video already attached to another meeting' do
    post_recording
    post_recording(body.merge(source_id: '11111111-aaaa-4aaa-8aaa-000000000002'))

    expect(json['error']).to eq('video_on_other_meeting')
  end

  it 'rejects malformed input', :aggregate_failures do
    post_recording(body.merge(video_id: 'not a video'))
    expect(response).to have_http_status(:unprocessable_content)

    post_recording(body.merge(metadata: { 'captions' => { 'en' => { 'source' => 'youtube_auto', 'vtt' => 'nope' } } }))
    expect(json['error']).to eq('invalid_metadata')
  end

  context 'when the publisher has not accepted the publishing agreement' do
    let(:accept_agreement) { false }

    it 'fails cleanly and leaves the meeting untouched', :aggregate_failures do
      post_recording

      expect(response).to have_http_status(:unprocessable_content)
      expect(json['error']).to eq('record_invalid')
      expect(meeting.recordings).to be_empty
    end
  end

  it 'rejects an oversized body' do
    post_recording(body.merge(metadata: metadata.merge('description' => 'x' * 4.megabytes)))

    expect(response).to have_http_status(:payload_too_large)
  end

  context 'with an OAuth application' do
    let(:owner) { manager.person }
    let(:application) { create(:oauth_application, owner:, scopes: 'read write_events') }
    let(:token) { create(:oauth_access_token, application:, scopes: scopes, resource_owner: nil).token }
    let(:oauth_headers) { { 'Authorization' => "Bearer #{token}", 'Content-Type' => 'application/json' } }

    context 'when granted a write scope' do
      let(:scopes) { 'read write_events' }

      it 'attaches the video' do
        post_recording(body, oauth_headers)

        expect(response).to have_http_status(:created)
      end
    end

    context 'when read only' do
      let(:scopes) { 'read' }

      it 'is refused for lack of scope', :aggregate_failures do
        post_recording(body, oauth_headers)

        expect(response).to have_http_status(:forbidden)
        expect(json['error']).to eq('insufficient_scope')
      end
    end
  end

  it 'refuses a signed-in person who is not a manager' do
    user = create(:user, :confirmed, password: 'SecureTest123!@#')
    post_recording(body, api_auth_headers(user, content_type: 'application/json'))

    expect(response).to have_http_status(:forbidden)
  end

  it 'refuses anonymous requests' do
    post_recording(body, { 'Content-Type' => 'application/json', 'Accept' => 'application/json' })

    expect(response).to have_http_status(:unauthorized)
  end
end
# rubocop:enable RSpec/ExampleLength, RSpec/MultipleExpectations, RSpec/MultipleMemoizedHelpers
