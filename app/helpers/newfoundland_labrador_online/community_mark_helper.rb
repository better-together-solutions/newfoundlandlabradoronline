# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # The one image that stands for a community wherever it is shown: its logo, else its profile image, never both.
  module CommunityMarkHelper
    # [:logo, attachment], [:profile_image, attachment] or nil when the community has neither.
    def community_mark(community)
      if community.logo.attached?
        [:logo, community.optimized_logo]
      elsif community.profile_image.attached?
        [:profile_image, community.optimized_profile_image]
      end
    end
  end
end
