# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # Host-side additions to BetterTogether::Post for the Corner Brook Online publisher:
  # categories by identifier and explicit contributors. Video input is in PostVideo.
  module Post
    extend ActiveSupport::Concern

    include NewfoundlandLabradorOnline::PostVideo

    included do
      validate :category_identifiers_must_exist
      validate :contributor_specs_must_be_supported
    end

    def category_identifiers
      categories.map(&:identifier)
    end

    def category_identifiers=(identifiers)
      @pending_category_identifiers = Array(identifiers).map(&:to_s).compact_blank.uniq
      found = ::BetterTogether::Category.where(identifier: @pending_category_identifiers).to_a
      self.categories = found if found.size == @pending_category_identifiers.size
    end

    def contributor_specs
      []
    end

    # Builds authorships at create time so CE's add_creator_as_author (which only
    # runs when no contributions exist) does not add the API actor as an extra author.
    def contributor_specs=(specs)
      Array(specs).each { |spec| build_contribution(spec.to_h.with_indifferent_access) }
    end

    private

    def build_contribution(spec)
      type = spec[:author_type].to_s
      unless ::BetterTogether::Authorship::AUTHOR_TYPES.include?(type)
        return (@unsupported_contributor_types ||= []) << type
      end

      contributions.build(
        author: type.constantize.find(spec[:author_id]),
        role: spec[:role].presence || ::BetterTogether::Authorship::AUTHOR_ROLE,
        contribution_type: spec[:contribution_type].presence || ::BetterTogether::Authorship::CONTENT_CONTRIBUTION,
        position: spec[:position]
      )
    end

    def contributor_specs_must_be_supported
      return if @unsupported_contributor_types.blank?

      errors.add(:base, "unsupported contributor type: #{@unsupported_contributor_types.join(', ')}")
    end

    def category_identifiers_must_exist
      return if @pending_category_identifiers.blank?

      known = ::BetterTogether::Category.where(identifier: @pending_category_identifiers).pluck(:identifier)
      missing = @pending_category_identifiers - known
      errors.add(:base, "unknown categories: #{missing.join(', ')}") if missing.any?
    end
  end
end
