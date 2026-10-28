# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # Host-side additions to BetterTogether::Post for the Corner Brook Online publisher:
  # explicit contributors (categories by identifier and pinned dates are CE's).
  module Post
    extend ActiveSupport::Concern

    included do
      validate :contributor_specs_must_be_supported
    end

    def contributor_specs
      []
    end

    # Builds authorships at create time so CE's add_creator_as_author (which only
    # runs when no contributions exist) does not add the API actor as an extra author.
    # Accepts a list of hashes or, from the JSON:API (which rejects nested objects), a JSON string.
    def contributor_specs=(specs)
      specs = JSON.parse(specs) if specs.is_a?(String)
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
  end
end
