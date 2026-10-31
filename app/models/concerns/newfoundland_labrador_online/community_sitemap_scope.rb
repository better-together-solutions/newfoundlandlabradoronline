# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # Keeps civic communities out of the sitemap; their canonical civic pages are the indexed entry points.
  module CommunitySitemapScope
    def sitemap_listable(platform)
      type = arel_table[:type]
      super.where(type.eq(nil).or(type.not_in(CommunityPolicyScope::CIVIC_TYPES)))
    end
  end
end
