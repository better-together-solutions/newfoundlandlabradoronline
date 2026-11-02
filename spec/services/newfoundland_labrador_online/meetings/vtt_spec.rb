# frozen_string_literal: true

require 'rails_helper'

RSpec.describe NewfoundlandLabradorOnline::Meetings::Vtt do
  let(:cues) { described_class.parse(Rails.root.join('spec/fixtures/meetings/youtube_auto.vtt').read) }

  it 'shows each spoken line once, dropping the rolling repeats and empty cues' do
    expect(cues.pluck('text')).to eq(['>> Mhm.', '>> Call the meeting to order.', 'Good evening everyone,',
                                      "move into tonight's agenda."])
  end

  it 'reads hours, minutes and milliseconds' do
    expect(cues.map { |cue| cue.values_at('start_ms', 'end_ms') }.last).to eq([16_657, 78_407])
  end

  it 'joins the cues into plain text' do
    expect(described_class.plain_text(cues).lines.size).to eq(4)
  end

  it 'gives no cues for text that is not WebVTT' do
    expect(described_class.parse('nothing here')).to eq([])
  end
end
