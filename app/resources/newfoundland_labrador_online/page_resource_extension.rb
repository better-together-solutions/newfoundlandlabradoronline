# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # Host-side API addition for BetterTogether::Api::V1::PageResource: categories by identifier, as for posts, so
  # generated pages (ships/*) can be filed under a category.
  module PageResourceExtension
    def self.prepended(base)
      base.attributes :category_identifiers
      base.singleton_class.prepend(ClassMethods)
    end

    # Class-level overrides
    module ClassMethods
      def creatable_fields(context)
        (super + %i[category_identifiers]).uniq
      end

      def updatable_fields(context)
        (super + %i[category_identifiers]).uniq
      end
    end
  end
end
