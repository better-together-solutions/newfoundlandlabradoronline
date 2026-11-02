# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable-next RSpec/MultipleExpectations
RSpec.describe NewfoundlandLabradorOnline::Meetings::EscribeSource do
  subject(:meetings) do
    described_class.new(config).parse(Rails.root.join('spec/fixtures/meetings/escribe_calendar.json').read)
  end

  let(:config) { { 'portal' => 'https://pub-example.escribemeetings.com/', 'time_zone' => 'America/St_Johns' } }
  let(:regular) { meetings.find { |m| m[:source_id].end_with?('001') } }

  it 'returns meetings oldest first' do
    expect(meetings.map { |m| m[:source_id][-3..] }).to eq(%w[003 001 002])
  end

  it 'keeps the minute but drops the meaningless seconds, in the portal time zone' do
    expect(regular[:starts_at]).to eq(Time.find_zone('America/St_Johns').local(2026, 10, 26, 19, 0, 0))
  end

  it 'maps document types and formats to absolute https links, ignoring unknown kinds' do
    expect(regular[:documents].map { |d| d.values_at(:kind, :format) })
      .to contain_exactly(%w[agenda pdf], %w[agenda_package pdf], %w[minutes pdf], %w[minutes html])
    expect(regular[:documents].map { |d| d[:url] }).to all(start_with('https://pub-example.escribemeetings.com/'))
  end

  it 'reports video links separately' do
    expect(regular[:video_urls]).to eq(['https://www.youtube.com/watch?v=abc123xyz00'])
  end

  it 'marks a meeting cancelled when the title says so' do
    expect(meetings.find { |m| m[:source_id].end_with?('002') }).to include(status: 'cancelled', location: nil)
  end

  it 'decodes HTML entities in names and drops plain http links' do
    planning = meetings.find { |m| m[:source_id].end_with?('003') }
    expect(planning[:title]).to eq('Planning & Works')
    expect(planning[:documents]).to be_empty
  end

  it 'falls back to the portal meeting page when no link is given' do
    expect(meetings.find { |m| m[:source_id].end_with?('002') }[:portal_url])
      .to start_with('https://pub-example.escribemeetings.com/Meeting.aspx?Id=')
  end
end
