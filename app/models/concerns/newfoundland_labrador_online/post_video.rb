# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # Create-time video input for posts: video_block_id names an existing
  # BetterTogether::Content::VideoBlock (created through the blocks API), which is attached
  # at the top of the body. Remove once CE posts can feature blocks natively.
  module PostVideo
    extend ActiveSupport::Concern

    included do
      attr_accessor :video_block_id

      validate :video_block_must_exist, on: :create
      before_create :attach_video_block
    end

    private

    def video_block_to_attach
      return if video_block_id.blank?

      ::BetterTogether::Content::VideoBlock.find_by(id: video_block_id, platform_id:)
    end

    def attach_video_block
      block = video_block_to_attach
      return unless block

      self.content = ActionText::Attachment.from_attachable(block).to_html + content.body.to_html.to_s
    end

    def video_block_must_exist
      return if video_block_id.blank? || video_block_to_attach

      errors.add(:video_block_id, :invalid)
    end
  end
end
