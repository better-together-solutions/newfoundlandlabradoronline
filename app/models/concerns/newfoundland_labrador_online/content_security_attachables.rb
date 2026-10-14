# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # Lets CE's rich-text security controls accept this app's own attachable classes.
  # CE rejects and holds every attachment that is not an ActiveStorage blob; each
  # extension only adds an exception for ALLOWED and defers to CE otherwise.
  module ContentSecurityAttachables
    ALLOWED = %w[BetterTogether::Content::VideoBlock].freeze

    def self.allowed?(attachable)
      ALLOWED.include?(attachable.class.name)
    end

    # Attached blocks are only rendered when public, so a signed id copied from a
    # restricted block cannot expose it through another record's body.
    def self.renderable?(attachable)
      allowed?(attachable) && attachable.privacy_public? && attachable.visible?
    end

    # Prepended to BetterTogether::ContentSecurity::ActionTextRichTextControls.
    module RichTextControls
      private

      def validate_supported_embeds_for_content_security
        others = body&.attachables.to_a.grep_v(::ActiveStorage::Blob)
        return super if others.empty?
        return if others.all? { |attachable| ContentSecurityAttachables.allowed?(attachable) }

        super
      end
    end

    # Prepended to BetterTogether::ContentSecurity::RichTextAttachmentFilter.
    module AttachmentFilter
      private

      def attachment_renderable?(attachment)
        return true if ContentSecurityAttachables.renderable?(attachment.attachable)

        super
      end
    end
  end
end
