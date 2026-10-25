# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # Write-only +attachment_block_ids+ on an event: existing blocks (an image) are appended to the end of the
  # description as Action Text attachments, so the full picture shows under the text. CE's BlockAttachments does
  # this for a post's content, at the top; an event's body is its description. A block already in the description
  # is not added twice, so sending the same ids again changes nothing. Blocks must be on the event's platform and
  # allowed by CE's attachable registry.
  module EventBlockAttachments
    extend ActiveSupport::Concern

    included do
      attr_accessor :attachment_block_ids

      validate :attachment_blocks_must_be_attachable, if: :attaching_blocks?
      before_save :append_attachment_blocks, if: :attaching_blocks?
      after_save { self.attachment_block_ids = nil }
    end

    private

    def attaching_blocks?
      Array(attachment_block_ids).compact_blank.any?
    end

    def attachable_block(id)
      block = BetterTogether::Content::Block.find_by(id:, platform_id:)
      block if block && BetterTogether::ContentSecurity::AttachableRegistry.allowed?(block)
    end

    def attachment_blocks_must_be_attachable
      return unless Array(attachment_block_ids).compact_blank.any? { |id| attachable_block(id).nil? }

      errors.add(:attachment_block_ids, :invalid)
    end

    def append_attachment_blocks
      html = new_attachments_html
      self.description = "#{description.body&.to_html}#{html}" if html.present?
    end

    def new_attachments_html
      fresh = attachable_blocks.reject { |block| attached_block_ids.include?(block.id) }
      fresh.map { |block| attachment_html(block) }.join
    end

    def attachable_blocks
      Array(attachment_block_ids).compact_blank.filter_map { |id| attachable_block(id) }
    end

    def attached_block_ids
      (description.body&.attachables || []).grep(BetterTogether::Content::Block).map(&:id)
    end

    def attachment_html(block)
      ActionText::Attachment.from_attachable(block).to_html
    end
  end
end
