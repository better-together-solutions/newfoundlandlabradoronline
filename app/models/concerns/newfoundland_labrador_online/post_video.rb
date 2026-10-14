# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # Host-side video input for posts: video_url/video_orientation become a VideoBlock
  # attached in the body. Remove once CE posts can feature blocks natively.
  module PostVideo
    extend ActiveSupport::Concern

    VIDEO_ORIENTATIONS = %w[landscape portrait].freeze

    included do
      validates :video_orientation, inclusion: { in: VIDEO_ORIENTATIONS }, allow_blank: true
      validate :video_url_must_be_supported
      before_save :sync_video_block
      after_save :clear_pending_video_input
      after_destroy :destroy_owned_video_block
    end

    # video_url and video_orientation are write-only inputs that become the video
    # attachment on save. Reads come from the attachment, never from a stored copy.
    attr_writer :video_url, :video_orientation

    # The attached video block (the first in the body).
    def video_block
      content.body&.attachables.to_a.grep(::BetterTogether::Content::VideoBlock).first
    end

    def video_url
      return @video_url if defined?(@video_url)

      video_block&.video_url
    end

    def video_orientation
      return @video_orientation if defined?(@video_orientation)
      return unless video_block

      video_block.portrait? ? 'portrait' : 'landscape'
    end

    private

    # Persists the post's own video block from the video input and attaches it at the
    # top of the body. The block is reused (updated in place) on later saves.
    def sync_video_block
      return unless video_input_present?

      block = owned_video_block || new_video_block
      block.assign_attributes(video_block_attributes(block))
      return abort_video_sync(block) unless block.save

      self.content = block_attachment_html(block) + content.body.to_html.to_s unless video_block == block
    end

    def video_input_present?
      return @video_url.present? if defined?(@video_url) && !defined?(@video_orientation)
      return false unless defined?(@video_url) || defined?(@video_orientation)

      (defined?(@video_url) && @video_url.present?) || owned_video_block.present?
    end

    def video_block_attributes(block)
      portrait = (defined?(@video_orientation) ? @video_orientation : video_orientation) == 'portrait'
      { video_url: defined?(@video_url) ? @video_url : block.video_url,
        aspect_ratio: portrait ? '9x16' : '16x9', privacy: privacy }
    end

    def block_attachment_html(block)
      ActionText::Attachment.from_attachable(block).to_html
    end

    def abort_video_sync(block)
      errors.add(:video_url, block.errors.full_messages.to_sentence)
      throw :abort
    end

    def video_block_identifier
      "video-#{identifier}"
    end

    def owned_video_block
      ::BetterTogether::Content::VideoBlock.find_by(platform:, identifier: video_block_identifier)
    end

    def new_video_block
      ::BetterTogether::Content::VideoBlock.new(platform:, identifier: video_block_identifier, creator:)
    end

    def destroy_owned_video_block
      owned_video_block&.destroy
    end

    def clear_pending_video_input
      remove_instance_variable(:@video_url) if defined?(@video_url)
      remove_instance_variable(:@video_orientation) if defined?(@video_orientation)
    end

    def video_url_must_be_supported
      return unless defined?(@video_url) && @video_url.present?
      return if %i[youtube vimeo].include?(::BetterTogether::Content::VideoBlock.new(video_url: @video_url).provider)

      errors.add(:video_url, :invalid)
    end
  end
end
