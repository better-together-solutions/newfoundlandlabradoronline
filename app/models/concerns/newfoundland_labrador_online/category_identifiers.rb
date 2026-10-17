# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # Categories by identifier for categorizable host content (posts, pages): the API sends identifiers and unknown
  # ones are rejected instead of silently dropped.
  module CategoryIdentifiers
    extend ActiveSupport::Concern

    included do
      validate :category_identifiers_must_exist
    end

    def category_identifiers
      categories.map(&:identifier)
    end

    def category_identifiers=(identifiers)
      @pending_category_identifiers = Array(identifiers).map(&:to_s).compact_blank.uniq
      found = ::BetterTogether::Category.where(identifier: @pending_category_identifiers).to_a
      self.categories = found if found.size == @pending_category_identifiers.size
    end

    private

    def category_identifiers_must_exist
      return if @pending_category_identifiers.blank?

      known = ::BetterTogether::Category.where(identifier: @pending_category_identifiers).pluck(:identifier)
      missing = @pending_category_identifiers - known
      errors.add(:base, "unknown categories: #{missing.join(', ')}") if missing.any?
    end
  end
end
