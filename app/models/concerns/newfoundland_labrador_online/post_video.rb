# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # Create-time attachments for posts: video_block_id and attachment_block_ids name existing blocks
  # (a video block or image blocks, created through the blocks API) which are attached at the top of
  # the body in that order. Remove once CE posts can feature blocks natively.
  module PostVideo
    extend ActiveSupport::Concern

    included do
      attr_accessor :video_block_id, :attachment_block_ids

      validate :attachment_blocks_must_exist, on: :create
      before_create :attach_blocks
    end

    private

    def block_ids_to_attach
      ([video_block_id] + Array(attachment_block_ids)).compact_blank
    end

    def attachable_block(id)
      block = ::BetterTogether::Content::Block.find_by(id:, platform_id:)
      block if block && ContentSecurityAttachables.allowed?(block)
    end

    def attach_blocks
      html = block_ids_to_attach.filter_map { |id| attachable_block(id) }
                                .map { |block| ActionText::Attachment.from_attachable(block).to_html }.join
      return if html.blank?

      self.content = html + content.body.to_html.to_s
    end

    def attachment_blocks_must_exist
      errors.add(:video_block_id, :invalid) if video_block_id.present? && attachable_block(video_block_id).nil?
      missing = Array(attachment_block_ids).compact_blank.any? { |id| attachable_block(id).nil? }
      errors.add(:attachment_block_ids, :invalid) if missing
    end
  end
end
