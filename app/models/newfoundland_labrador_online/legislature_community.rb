# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # Legislature communities: a Community subtype (STI on the type column).
  class LegislatureCommunity < BetterTogether::Community
    include BetterTogether::CommunitySubtype

    has_one :legislature_detail, class_name: 'NewfoundlandLabradorOnline::LegislatureDetail',
                                 foreign_key: :community_id, inverse_of: :community, dependent: :destroy

    # The settlement of a municipal council; nil for any other legislature.
    def municipal_settlement
      detail = legislature_detail
      return unless detail&.level == 'municipal' && detail.jurisdiction.is_a?(BetterTogether::Geography::Settlement)

      detail.jurisdiction
    end
  end
end
