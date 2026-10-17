# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # Attachments for posts: video_block_id and attachment_block_ids name existing blocks (a video block or
  # image blocks, created through the blocks API) which are attached at the top of the body in that order.
  # A body update keeps the post's image blocks: an update that carries new text without any attachment
  # puts the existing attachments back in front of it, and attachment_block_ids sent on update replace them.
  # Remove once CE posts can feature blocks natively.
  module PostVideo
    extend ActiveSupport::Concern

    included do
      attr_accessor :video_block_id, :attachment_block_ids

      validate :attachment_blocks_must_exist, if: :attaching_blocks?
      before_create :attach_blocks
      before_update :attach_blocks, if: :attaching_blocks?
      before_update :keep_attachments, unless: :attaching_blocks?
      after_save { self.attachment_block_ids = nil }
    end

    private

    def attaching_blocks?
      new_record? || Array(attachment_block_ids).compact_blank.any?
    end

    def block_ids_to_attach
      ids = Array(attachment_block_ids)
      (new_record? ? [video_block_id] + ids : ids).compact_blank
    end

    def attachable_block(id)
      block = ::BetterTogether::Content::Block.find_by(id:, platform_id:)
      block if block && ContentSecurityAttachables.allowed?(block)
    end

    def block_attachables(record)
      record.content.body.attachables.grep(::BetterTogether::Content::Block)
    end

    # New text sent without attachments must not drop the blocks the post already shows.
    def keep_attachments
      return unless persisted? && block_attachables(self).empty?

      html = attachments_html(block_attachables(::BetterTogether::Post.find(id)))
      self.content = html + content.body.to_html.to_s if html.present?
    end

    def attachments_html(blocks)
      blocks.map { |block| ActionText::Attachment.from_attachable(block).to_html }.join
    end

    def attach_blocks
      html = attachments_html(block_ids_to_attach.filter_map { |id| attachable_block(id) })
      return if html.blank?

      self.content = html + content.body.to_html.to_s
    end

    def attachment_blocks_must_exist
      errors.add(:video_block_id, :invalid) if new_record? && unattachable?(video_block_id)
      return unless Array(attachment_block_ids).compact_blank.any? { |id| unattachable?(id) }

      errors.add(:attachment_block_ids, :invalid)
    end

    def unattachable?(id)
      id.present? && attachable_block(id).nil?
    end
  end
end
