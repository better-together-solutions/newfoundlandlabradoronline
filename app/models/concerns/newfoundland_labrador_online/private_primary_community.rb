# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # Keeps a record's auto-created primary community private, so it never appears in a communities directory.
  # (People's and regions' communities are placeholders for future personal and civic memberships.) The community
  # is created at the record's own privacy because the ceiling check needs that, then set private directly.
  module PrivatePrimaryCommunity
    extend ActiveSupport::Concern

    included do
      after_save :keep_primary_community_private
    end

    private

    def keep_primary_community_private
      community.update_columns(privacy: 'private') if community && !community.privacy_private?
    end
  end
end
