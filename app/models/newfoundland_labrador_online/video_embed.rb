# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # A YouTube video embedded in rich text as an Action Text attachment (the same
  # GlobalID mechanism used for @mentions). The id is "<youtube id>:<orientation>".
  class VideoEmbed
    include ActiveModel::Model
    include GlobalID::Identification
    include ActionText::Attachable

    ORIENTATIONS = %w[landscape portrait].freeze
    YOUTUBE_ID = /\A[\w-]{11}\z/
    EMBED_HOST = 'https://www.youtube-nocookie.com/embed/'

    attr_reader :youtube_id, :orientation

    class << self
      def find(id)
        youtube_id, orientation = id.to_s.split(':', 2)
        orientation = 'landscape' if orientation.blank?
        raise ActiveRecord::RecordNotFound, "Invalid video embed #{id}" unless valid?(youtube_id, orientation)

        new(youtube_id:, orientation:)
      end

      def from_url(url, orientation: nil)
        block = ::BetterTogether::Content::VideoBlock.new(video_url: url)
        youtube_id = block.embed_url.to_s[%r{/embed/([\w-]{11})\z}, 1]
        return unless block.provider == :youtube && youtube_id

        new(youtube_id:,
            orientation: orientation.presence || (url.to_s.include?('/shorts/') ? 'portrait' : 'landscape'))
      end

      def valid?(youtube_id, orientation)
        YOUTUBE_ID.match?(youtube_id.to_s) && ORIENTATIONS.include?(orientation)
      end
    end

    def initialize(youtube_id:, orientation: 'landscape')
      super()
      @youtube_id = youtube_id
      @orientation = orientation
    end

    def id
      "#{youtube_id}:#{orientation}"
    end

    def embed_url
      "#{EMBED_HOST}#{youtube_id}"
    end

    def watch_url
      return "https://www.youtube.com/shorts/#{youtube_id}" if orientation == 'portrait'

      "https://www.youtube.com/watch?v=#{youtube_id}"
    end

    def aspect_ratio
      orientation == 'portrait' ? '9x16' : '16x9'
    end

    def attachment_html
      ActionText::Attachment.from_attachable(self).to_html
    end

    def ==(other)
      other.is_a?(self.class) && other.id == id
    end
    alias eql? ==

    def hash
      id.hash
    end

    def to_param
      id
    end

    def attachable_plain_text_representation(_caption = nil)
      '[Video]'
    end

    def to_attachable_partial_path
      'newfoundland_labrador_online/video_embeds/video_embed'
    end

    def to_trix_content_attachment_partial_path
      'newfoundland_labrador_online/video_embeds/trix'
    end
  end
end
