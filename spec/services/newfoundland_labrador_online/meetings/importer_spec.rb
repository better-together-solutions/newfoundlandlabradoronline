# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable-next RSpec/ExampleLength, RSpec/MultipleExpectations
RSpec.describe NewfoundlandLabradorOnline::Meetings::Importer do
  include RequestSpecHelper

  let(:settlement) { BetterTogether::Geography::Settlement.friendly.find('corner-brook') }
  let(:council) { NewfoundlandLabradorOnline::Civic::Municipality.for(settlement).council }
  let(:meeting) { NewfoundlandLabradorOnline::Meeting.find_by!(source_id: '11111111-aaaa-4aaa-8aaa-000000000001') }

  before do
    configure_host_platform
    corner_brook_council
  end

  it 'writes nothing unless applying, but reports what it would do' do
    result = import_meetings(apply: false)

    expect(result.counts).to eq(created: 3, updated: 0, unchanged: 0)
    expect(NewfoundlandLabradorOnline::Meeting.count + BetterTogether::Event.count).to eq(0)
  end

  it 'creates meetings with link-out documents and no stored files', :aggregate_failures do
    import_meetings

    expect(meeting).to have_attributes(body: council, body_key: 'regular', status: 'held', location: 'Council Chambers')
    expect(meeting.documents.pluck(:kind, :format)).to contain_exactly(%w[agenda pdf], %w[agenda_package pdf],
                                                                       %w[minutes pdf], %w[minutes html])
    expect(meeting.documents.pluck(:url)).to all(start_with('https://pub-example.escribemeetings.com/'))
  end

  it 'gives every meeting a public 120 minute event hosted by the council', :aggregate_failures do
    import_meetings
    event = meeting.event

    expect(event).to have_attributes(duration_minutes: 120, privacy: 'public', status: 'confirmed',
                                     timezone: 'America/St_Johns', starts_at: meeting.starts_at)
    expect(event.event_hosts.map(&:host)).to eq([council])
  end

  it 'tags events with a meeting category per body, with icon and colour', :aggregate_failures do
    import_meetings

    category = meeting.category
    expect(category).to be_a(NewfoundlandLabradorOnline::MeetingCategory)
    expect(category).to have_attributes(identifier: 'meeting-regular', icon: 'fas fa-landmark', color: '#0072B2')
    expect(BetterTogether::EventCategory.where(identifier: 'meeting-regular')).to include(category)
  end

  it 'marks cancelled meetings and their events' do
    import_meetings
    cancelled = NewfoundlandLabradorOnline::Meeting.find_by!(source_id: '11111111-aaaa-4aaa-8aaa-000000000002')

    expect([cancelled.status, cancelled.event.status]).to eq(%w[cancelled cancelled])
  end

  it 'is idempotent and updates only what changed', :aggregate_failures do
    import_meetings
    expect(import_meetings.counts).to eq(created: 0, updated: 0, unchanged: 3)

    changed = fixture_meetings.map { |m| m[:source_id].end_with?('003') ? m.merge(location: 'Room 9') : m }
    expect(import_meetings(meetings: changed).counts).to eq(created: 0, updated: 1, unchanged: 2)
    expect(NewfoundlandLabradorOnline::Meeting.count).to eq(3)
    expect(BetterTogether::Event.where('source_id LIKE ?', 'cornerbrook:%').count).to eq(3)
  end

  it 'drops documents the portal no longer lists' do
    import_meetings
    trimmed = fixture_meetings.map do |m|
      m[:source_id].end_with?('001') ? m.merge(documents: m[:documents].first(1)) : m
    end
    import_meetings(meetings: trimmed)

    expect(meeting.documents.count).to eq(1)
  end

  it 'reports a missing council instead of failing' do
    NewfoundlandLabradorOnline::Meeting.delete_all
    result = described_class.new(source_key: 'x', config: meeting_config.merge('council' => 'nowhere'),
                                 meetings: fixture_meetings, apply: true).call

    expect(result.missing_bodies).to eq(['nowhere'])
  end
end
