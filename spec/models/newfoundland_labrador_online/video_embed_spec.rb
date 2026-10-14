# frozen_string_literal: true

require 'rails_helper'

RSpec.describe NewfoundlandLabradorOnline::VideoEmbed do
  subject(:embed) { described_class.new(youtube_id: 'dQw4w9WgXcQ', orientation: 'portrait') }

  describe '.from_url' do
    it 'reads watch urls' do
      expect(described_class.from_url('https://www.youtube.com/watch?v=dQw4w9WgXcQ')).to have_attributes(
        youtube_id: 'dQw4w9WgXcQ', orientation: 'landscape'
      )
    end

    it 'reads Shorts urls with the given orientation' do
      expect(described_class.from_url('https://www.youtube.com/shorts/dQw4w9WgXcQ', orientation: 'portrait'))
        .to have_attributes(youtube_id: 'dQw4w9WgXcQ', orientation: 'portrait')
    end

    it 'infers portrait from a Shorts url without an orientation' do
      expect(described_class.from_url('https://www.youtube.com/shorts/dQw4w9WgXcQ').orientation).to eq('portrait')
    end

    it 'returns nil for other providers and hosts', :aggregate_failures do
      expect(described_class.from_url('https://vimeo.com/123456789')).to be_nil
      expect(described_class.from_url('https://example.com/a.mp4')).to be_nil
    end
  end

  describe '.find' do
    it 'locates by id' do
      expect(described_class.find('dQw4w9WgXcQ:portrait')).to eq(embed)
    end

    it 'defaults the orientation' do
      expect(described_class.find('dQw4w9WgXcQ').orientation).to eq('landscape')
    end

    it 'raises for malformed ids', :aggregate_failures do
      expect { described_class.find('short:portrait') }.to raise_error(ActiveRecord::RecordNotFound)
      expect { described_class.find('dQw4w9WgXcQ:square') }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  it 'uses the privacy-enhanced embed host and an orientation aspect ratio', :aggregate_failures do
    expect(embed.embed_url).to eq('https://www.youtube-nocookie.com/embed/dQw4w9WgXcQ')
    expect(embed.aspect_ratio).to eq('9x16')
    expect(described_class.new(youtube_id: 'dQw4w9WgXcQ').aspect_ratio).to eq('16x9')
  end

  it 'builds watch urls by orientation', :aggregate_failures do
    expect(embed.watch_url).to eq('https://www.youtube.com/shorts/dQw4w9WgXcQ')
    expect(described_class.new(youtube_id: 'dQw4w9WgXcQ').watch_url).to eq('https://www.youtube.com/watch?v=dQw4w9WgXcQ')
  end

  it 'round trips through a signed global id' do
    sgid = embed.attachable_sgid

    expect(ActionText::Attachable.from_attachable_sgid(sgid)).to eq(embed)
  end

  it 'survives a Trix round trip as an attachment', :aggregate_failures do
    trix_html = ActionText::Content.new(embed.attachment_html).to_trix_html

    expect(trix_html).to include('data-trix-attachment', 'Video (portrait)')
    expect(ActionText::Content.new(embed.attachment_html).attachables).to eq([embed])
  end
end
