# frozen_string_literal: true

require 'rails_helper'

RSpec.describe NewfoundlandLabradorOnline::ContentSecurityAttachables do
  let(:platform) { BetterTogether::Platform.find_by(host: true) || create(:better_together_platform) }
  let(:person) { create(:better_together_person) }
  let(:embed) { NewfoundlandLabradorOnline::VideoEmbed.new(youtube_id: 'dQw4w9WgXcQ') }
  let(:other_attachable) do
    Class.new do
      include GlobalID::Identification
      include ActionText::Attachable

      def self.name = 'SomeOtherAttachable'
      def self.find(_id) = new
      def id = 'x'
    end
  end

  def new_post(content)
    BetterTogether::Post.new(title: 'T', identifier: "att-#{SecureRandom.hex(4)}", platform:, privacy: 'private',
                             creator: person, content:)
  end

  def render_content(content)
    BetterTogether::PostsController.render(inline: '<%= render_action_text_content(c) %>', locals: { c: content })
  end

  describe 'rich text validation' do
    it 'accepts the video attachable', :aggregate_failures do
      post = new_post("<div>Hi</div>#{embed.attachment_html}")

      expect(post).to be_valid
      expect(post.save).to be(true)
    end

    it 'still rejects other non-blob attachables' do
      allow(other_attachable).to receive(:find).and_return(other_attachable.new)
      stub_const('SomeOtherAttachable', other_attachable)
      post = new_post(ActionText::Attachment.from_attachable(other_attachable.new).to_html)

      expect(post).not_to be_valid
    end
  end

  describe 'rendering' do
    it 'renders the video iframe for the attachable', :aggregate_failures do
      html = render_content(ActionText::Content.new("<div>Hi</div>#{embed.attachment_html}"))

      expect(html).to include('youtube-nocookie.com/embed/dQw4w9WgXcQ', 'ratio-16x9', 'post-video--landscape')
      expect(html).not_to include('held-review')
    end

    it 'renders portrait videos in a 9x16 frame' do
      portrait = NewfoundlandLabradorOnline::VideoEmbed.new(youtube_id: 'dQw4w9WgXcQ', orientation: 'portrait')

      expect(render_content(ActionText::Content.new(portrait.attachment_html))).to include('ratio-9x16')
    end

    it 'strips iframes that are not part of a video attachment', :aggregate_failures do
      html = render_content(ActionText::Content.new(
                              '<iframe src="https://www.youtube-nocookie.com/embed/dQw4w9WgXcQ"></iframe>' \
                              '<iframe src="https://evil.example/x"></iframe>'
                            ))

      expect(html).not_to include('<iframe')
    end
  end
end
