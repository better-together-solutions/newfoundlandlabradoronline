# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # Host-side API additions for BetterTogether::Api::V1::BlockResource: write-only base64 image input
  # (CE's blocks API has no file field): media_data for image blocks and background_image_data for hero
  # blocks, each with a filename. Send block_type before the image fields.
  module BlockResourceExtension
    WRITE_ONLY_FIELDS = %i[media_data media_filename background_image_data background_image_filename].freeze
    # CE's blocks API exposes an image's attribution text but not the link it should point to.
    ATTRIBUTION_URL_FIELDS = %w[en fr es uk].map { |locale| :"attribution_url_#{locale}" }.freeze
    WRITABLE_FIELDS = (WRITE_ONLY_FIELDS + ATTRIBUTION_URL_FIELDS).freeze

    def self.prepended(base)
      ATTRIBUTION_URL_FIELDS.each do |field|
        # guarded like CE's own block fields: other block types have no such accessor
        base.define_method(field) { _model.respond_to?(field) ? _model.public_send(field) : nil }
        base.define_method(:"#{field}=") do |value|
          _model.public_send(:"#{field}=", value) if _model.respond_to?(:"#{field}=")
        end
      end
      base.attributes(*WRITE_ONLY_FIELDS, *ATTRIBUTION_URL_FIELDS)
      base.singleton_class.prepend(ClassMethods)
    end

    # Class-level overrides
    module ClassMethods
      def creatable_fields(context)
        (super + WRITABLE_FIELDS).uniq
      end

      def updatable_fields(context)
        (super + WRITABLE_FIELDS).uniq
      end
    end

    WRITE_ONLY_FIELDS.each do |field|
      define_method(:"#{field}=") do |value|
        unless _model.respond_to?(:"#{field}=")
          raise JSONAPI::Exceptions::InvalidFieldValue.new(field, 'is not valid for this block type')
        end

        _model.public_send(:"#{field}=", value)
      end
    end

    def fetchable_fields
      super - WRITE_ONLY_FIELDS
    end
  end
end
