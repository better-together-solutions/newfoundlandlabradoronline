# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # video_block_id names an existing video block (created through the blocks API) to attach at the top of the body
  # of a new post, ahead of CE's attachment_block_ids (BetterTogether::BlockAttachments does the attaching).
  # Remove once CE posts take a featured video natively.
  module PostVideo
    extend ActiveSupport::Concern

    included do
      attr_accessor :video_block_id

      validate :video_block_must_exist, if: -> { new_record? && video_block_id.present? }
      before_validation :queue_video_block, on: :create, if: -> { video_block_id.present? }
      after_save { self.video_block_id = nil }
    end

    private

    def queue_video_block
      return unless attachable_block(video_block_id)

      self.attachment_block_ids = [video_block_id, *Array(attachment_block_ids)]
    end

    def video_block_must_exist
      errors.add(:video_block_id, :invalid) if attachable_block(video_block_id).nil?
    end
  end
end
