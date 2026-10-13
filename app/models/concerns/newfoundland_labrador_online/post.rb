# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # Temporary host-side video fields for Corner Brook Online posts. Removed once
  # CE posts can feature video blocks (see nlo:posts:migrate_video_urls_to_blocks).
  module Post
    extend ActiveSupport::Concern

    VIDEO_ORIENTATIONS = %w[landscape portrait].freeze
    YOUTUBE_EMBED_HOST = 'https://www.youtube-nocookie.com/embed/'

    included do
      store_attributes :display_settings do
        video_url String
        video_orientation String
        legacy_video_embed ::Virtus::Attribute::Boolean, default: false
      end

      validates :video_orientation, inclusion: { in: VIDEO_ORIENTATIONS }, allow_blank: true
      validate :video_url_must_be_supported
      validate :category_identifiers_must_exist
      validate :contributor_specs_must_be_supported
    end

    def video_block
      return if video_url.blank?

      @video_block ||= ::BetterTogether::Content::VideoBlock.new(video_url:)
    end

    def video_embed_url
      return unless video_block

      url = video_block.embed_url
      return url unless video_block.provider == :youtube

      url.sub(%r{\Ahttps://www\.youtube\.com/embed/}, YOUTUBE_EMBED_HOST)
    end

    def video_aspect_ratio
      video_orientation == 'portrait' ? '9x16' : '16x9'
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

    def video_url_must_be_supported
      return if video_url.blank?
      return if %i[youtube vimeo].include?(video_block.provider)

      errors.add(:video_url, :invalid)
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
