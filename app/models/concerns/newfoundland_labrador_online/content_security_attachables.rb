# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # Lets CE's rich-text security controls accept this app's own attachable classes.
  # CE rejects and holds every attachment that is not an ActiveStorage blob; each
  # extension only adds an exception for ALLOWED and defers to CE otherwise.
  module ContentSecurityAttachables
    ALLOWED = %w[NewfoundlandLabradorOnline::VideoEmbed].freeze

    def self.allowed?(attachable)
      ALLOWED.include?(attachable.class.name)
    end

    # Prepended to BetterTogether::ContentSecurity::ActionTextRichTextControls.
    module RichTextControls
      private

      def validate_supported_embeds_for_content_security
        others = body&.attachables.to_a.grep_v(::ActiveStorage::Blob)
        return if others.all? { |attachable| ContentSecurityAttachables.allowed?(attachable) }

        super
      end
    end

    # Prepended to BetterTogether::ContentSecurity::RichTextAttachmentFilter.
    module AttachmentFilter
      private

      def attachment_renderable?(attachment)
        return true if ContentSecurityAttachables.allowed?(attachment.attachable)

        super
      end
    end
  end
end
