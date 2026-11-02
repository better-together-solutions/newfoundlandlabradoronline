# frozen_string_literal: true

require 'rails_helper'

RSpec.describe NewfoundlandLabradorOnline::Meetings::VideoProvider do
  let(:youtube) { described_class::Youtube }

  {
    'https://www.youtube.com/watch?v=abc123xyz00' => 'abc123xyz00',
    'https://youtu.be/abc123xyz00' => 'abc123xyz00',
    'https://www.youtube.com/live/abc123xyz00' => 'abc123xyz00',
    'https://www.youtube.com/embed/abc123xyz00' => 'abc123xyz00'
  }.each do |url, ref|
    it "finds the video in #{url}" do
      expect(described_class.identify(url).reference_from(url)).to eq(ref)
    end
  end

  it 'ignores links that are not an https YouTube video', :aggregate_failures do
    ['http://www.youtube.com/watch?v=abc123xyz00', 'https://example.com/watch?v=abc123xyz00',
     'https://www.youtube.com/watch?v=short', 'https://www.youtube.com/@cityofcornerbrook', 'not a url',
     nil].each do |url|
      expect(described_class.identify(url)).to be_nil
    end
  end

  it 'builds the watch link and the privacy-enhanced embed' do
    expect([youtube.watch_url('abc123xyz00'), youtube.embed_url('abc123xyz00')])
      .to eq(['https://www.youtube.com/watch?v=abc123xyz00', 'https://www.youtube-nocookie.com/embed/abc123xyz00'])
  end
end
