# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::ContentSecurity::AttachableRegistry do
  let(:platform) { BetterTogether::Platform.find_by(host: true) || create(:better_together_platform) }
  let(:person) { create(:better_together_person) }
  let(:embed) do
    BetterTogether::Content::VideoBlock.create!(platform:, privacy: 'public', identifier: 'att-vb', creator: person,
                                                seed_privacy_ceiling_exempt: true,
                                                video_url: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ')
  end
  let(:image) do
    png = Base64.strict_decode64(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=='
    )
    BetterTogether::Content::Image.create!(platform:, privacy: 'public', identifier: 'att-img', creator: person,
                                           seed_privacy_ceiling_exempt: true, caption: 'Noon, 12:00',
                                           media_data: Base64.strict_encode64(png), media_filename: 'noon.png')
  end
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
      post = new_post("<div>Hi</div>#{ActionText::Attachment.from_attachable(embed).to_html}")

      expect(post).to be_valid
      expect(post.save).to be(true)
    end

    it 'accepts the image attachable', :aggregate_failures do
      post = new_post("<div>Hi</div>#{ActionText::Attachment.from_attachable(image).to_html}")

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
      html = render_content(ActionText::Content.new("<div>Hi</div>#{ActionText::Attachment.from_attachable(embed).to_html}"))

      expect(html).to include('youtube-nocookie.com/embed/dQw4w9WgXcQ', 'ratio-16x9', 'post-video--landscape')
      expect(html).not_to include('held-review')
    end

    it 'renders portrait videos in a 9x16 frame' do
      embed.update!(aspect_ratio: '9x16')
      html = render_content(ActionText::Content.new(ActionText::Attachment.from_attachable(embed).to_html))

      expect(html).to include('ratio-9x16', 'post-video--portrait')
    end

    it 'renders the image with its caption', :aggregate_failures do
      html = render_content(ActionText::Content.new(ActionText::Attachment.from_attachable(image).to_html))

      expect(html).to include('<img', 'Noon, 12:00', 'figure-caption', 'alt="Noon, 12:00"')
      expect(html).not_to include('held-review')
    end

    it 'serves the image from this host even when an asset host is configured', :aggregate_failures do
      allow(ActionController::Base).to receive(:asset_host).and_return('https://cdn.example.test')
      html = render_content(ActionText::Content.new(ActionText::Attachment.from_attachable(image).to_html))

      expect(html).to include('src="/rails/active_storage/blobs/proxy/')
      expect(html).not_to include('cdn.example.test')
    end

    it 'renders without the route helpers of a web controller (the API renders post content)' do
      content = ActionText::Content.new(ActionText::Attachment.from_attachable(image).to_html)
      html = ApplicationController.render(inline: '<%= render_action_text_content(c) %>', locals: { c: content })

      expect(html).to include('<img', 'Noon, 12:00')
    end

    it 'holds images that are not public' do
      image.update!(privacy: 'private')
      html = render_content(ActionText::Content.new(ActionText::Attachment.from_attachable(image).to_html))

      expect(html).not_to include('<img')
    end

    it 'holds blocks that are not public', :aggregate_failures do
      embed.update!(privacy: 'private')
      html = render_content(ActionText::Content.new(ActionText::Attachment.from_attachable(embed).to_html))

      expect(html).not_to include('youtube-nocookie.com')
      expect(html).to include('held-review')
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
