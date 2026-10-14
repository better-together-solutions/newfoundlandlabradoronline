# frozen_string_literal: true

require 'rails_helper'

RSpec.describe NewfoundlandLabradorOnline::VideoBlockScrubber do
  def sanitize(html)
    Rails::HTML5::SafeListSanitizer.new.sanitize(html, scrubber: described_class.new)
  end

  let(:embed_src) { 'https://www.youtube-nocookie.com/embed/dQw4w9WgXcQ' }

  it 'keeps the nocookie iframe inside an attachment', :aggregate_failures do
    html = sanitize(
      %(<action-text-attachment><iframe src="#{embed_src}" allowfullscreen></iframe></action-text-attachment>)
    )

    expect(html).to include(embed_src, 'allowfullscreen')
  end

  it 'removes the same iframe outside an attachment' do
    expect(sanitize(%(<iframe src="#{embed_src}"></iframe>))).not_to include('iframe')
  end

  it 'removes iframes from other hosts inside an attachment' do
    html = sanitize('<action-text-attachment><iframe src="https://www.youtube.com/embed/dQw4w9WgXcQ"></iframe>' \
                    '</action-text-attachment>')

    expect(html).not_to include('iframe')
  end

  it 'still removes scripts and keeps CE allowed markup', :aggregate_failures do
    html = sanitize('<p style="color:red">ok</p><script>alert(1)</script>')

    expect(html).to include('<p style="color:red;">ok</p>')
    expect(html).not_to include('script')
  end

  it 'leaves ordinary rich text unchanged', :aggregate_failures do
    html = '<h2>Title</h2><p>Text <a href="https://example.com/x">link</a> <strong>bold</strong></p>' \
           '<blockquote>Quote</blockquote><ul><li>One</li></ul>'

    expect(sanitize(html)).to eq(html)
  end

  it 'still removes dangerous links and handlers', :aggregate_failures do
    html = sanitize('<a href="javascript:alert(1)" onclick="x()">go</a><img src="x" onerror="y()">')

    expect(html).not_to include('javascript:', 'onclick', 'onerror')
  end
end
