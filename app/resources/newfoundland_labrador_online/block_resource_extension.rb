# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # Host-side API additions for BetterTogether::Api::V1::BlockResource: write-only base64 image input
  # for image blocks (CE's blocks API has no file field). Send block_type before media_data.
  module BlockResourceExtension
    WRITE_ONLY_FIELDS = %i[media_data media_filename].freeze

    def self.prepended(base)
      base.attributes(*WRITE_ONLY_FIELDS)
      base.singleton_class.prepend(ClassMethods)
    end

    # Class-level overrides
    module ClassMethods
      def creatable_fields(context)
        (super + WRITE_ONLY_FIELDS).uniq
      end

      def updatable_fields(context)
        (super + WRITE_ONLY_FIELDS).uniq
      end
    end

    WRITE_ONLY_FIELDS.each do |field|
      define_method(:"#{field}=") do |value|
        unless _model.respond_to?(:"#{field}=")
          raise JSONAPI::Exceptions::InvalidFieldValue.new(field, 'is only valid for image blocks')
        end

        _model.public_send(:"#{field}=", value)
      end
    end

    def fetchable_fields
      super - WRITE_ONLY_FIELDS
    end
  end
end
