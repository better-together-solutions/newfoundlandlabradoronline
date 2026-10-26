# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # A party within one jurisdiction (provincial parties also belong to their province). A provincial party and its
  # federal counterpart are separate records; how they are connected is modelled with the federal work.
  class PoliticalParty < BetterTogether::ApplicationRecord
    self.table_name = 'political_parties'
    FALLBACK_COLOR = '#6c757d'
    has_one_attached :logo do |attachable|
      attachable.variant :optimized_jpeg, resize_to_limit: [400, 200], format: 'jpg', preprocessed: true,
                                          saver: { strip: true, quality: 90, interlace: true }
      attachable.variant :optimized_png, resize_to_limit: [400, 200], format: 'png', preprocessed: true,
                                         saver: { strip: true, quality: 90 }
    end
    # Adds remove_logo and purges the blob when it is cleared; destroying the party purges it too.
    include BetterTogether::RemoveableAttachment

    belongs_to :state, class_name: 'BetterTogether::Geography::State', optional: true, inverse_of: :political_parties
    belongs_to :community, class_name: 'NewfoundlandLabradorOnline::PartyCommunity', optional: true,
                           inverse_of: :political_party
    has_many :memberships, class_name: 'NewfoundlandLabradorOnline::PartyMembership', dependent: :destroy,
                           inverse_of: :political_party
    has_many :elected_terms, class_name: 'NewfoundlandLabradorOnline::ElectedTerm', dependent: :nullify,
                             inverse_of: :political_party

    # Parties that have ever had a member elected; others that only contested are not listed.
    scope :ever_seated, lambda {
      where(community_id: BetterTogether::PersonCommunityMembership.select(:joinable_id))
    }

    validates :jurisdiction, :identifier, :name, :short_name, presence: true
    validates :color, format: { with: /\A#\h{6}\z/ }, allow_nil: true

    # Party records and their logos are public reference data; CE's blob gate asks the record this.
    def privacy_public? = true

    # Same variant selection as CE's Community#optimized_logo: SVG as is, PNG keeps transparency, else JPEG.
    def optimized_logo
      return logo if logo.content_type == 'image/svg+xml'

      logo.variant(logo.content_type == 'image/png' ? :optimized_png : :optimized_jpeg)
    end

    def display_color
      color.presence || FALLBACK_COLOR
    end
  end
end
