# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # The known relations between communities. Source is the parent (or the organisation joined); the target side is
  # the one whose joining the participation mode governs.
  module CommunityAssociationRegistry
    Relation = Struct.new(:kind, :symmetric, :inverse, :participation, keyword_init: true)

    RELATIONS = {
      'committee_of' => Relation.new(kind: 'hierarchy', symmetric: false, inverse: 'has_committee',
                                     participation: 'members_only'),
      'drawn_from' => Relation.new(kind: 'hierarchy', symmetric: false, inverse: 'draws_members',
                                   participation: 'members_only'),
      'administers' => Relation.new(kind: 'hierarchy', symmetric: false, inverse: 'administered_by',
                                    participation: 'none'),
      'caucus_of' => Relation.new(kind: 'hierarchy', symmetric: false, inverse: 'has_caucus',
                                  participation: 'members_only'),
      'governing_party' => Relation.new(kind: 'peer', symmetric: false, inverse: 'governs_with',
                                        participation: 'members_only'),
      'coalition_partner' => Relation.new(kind: 'peer', symmetric: true, inverse: 'coalition_partner',
                                          participation: 'none'),
      'member_of' => Relation.new(kind: 'membership', symmetric: false, inverse: 'has_member',
                                  participation: 'none'),
      'affiliate' => Relation.new(kind: 'membership', symmetric: false, inverse: 'has_affiliate',
                                  participation: 'none')
    }.freeze

    PARTICIPATIONS = %w[members_only members_and_invited open none].freeze

    def self.fetch(name)
      RELATIONS[name.to_s]
    end

    def self.names
      RELATIONS.keys
    end
  end
end
