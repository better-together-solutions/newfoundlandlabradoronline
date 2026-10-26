# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # A link between two communities (hierarchy, peer or membership) that says who may join the target community.
  class CommunityAssociation < BetterTogether::ApplicationRecord
    self.table_name = 'community_associations'
    PRIVACY_RANK = { 'private' => 0, 'community' => 1, 'public' => 2 }.freeze

    belongs_to :source_community, class_name: 'BetterTogether::Community'
    belongs_to :target_community, class_name: 'BetterTogether::Community'

    validates :relation, inclusion: { in: ->(_) { CommunityAssociationRegistry.names } }
    validates :participation, inclusion: { in: CommunityAssociationRegistry::PARTICIPATIONS }
    validates :target_community_id, uniqueness: { scope: %i[source_community_id relation starts_on] }
    validate :communities_differ
    validate :window_is_ordered
    validate :hierarchy_has_no_cycle
    validate :child_not_more_public_than_parent

    before_validation :apply_registry_defaults

    scope :hierarchy, -> { where(kind: 'hierarchy') }
    scope :active_on, lambda { |date|
      d = date.to_date
      t = arel_table
      where(t[:starts_on].eq(nil).or(t[:starts_on].lteq(d))).where(t[:ends_on].eq(nil).or(t[:ends_on].gteq(d)))
    }

    private

    def apply_registry_defaults
      definition = CommunityAssociationRegistry.fetch(relation)
      return unless definition

      self.kind = definition.kind
      self.participation = definition.participation if participation.blank?
    end

    def communities_differ
      errors.add(:target_community, 'must differ from the source') if source_community_id == target_community_id
    end

    def window_is_ordered
      return unless starts_on && ends_on && ends_on < starts_on

      errors.add(:ends_on, 'must not be before the start')
    end

    def hierarchy_has_no_cycle
      return unless kind == 'hierarchy' && source_community && target_community
      return if source_community_id == target_community_id

      return unless target_community.descendant_ids.include?(source_community_id)

      errors.add(:base, 'would make a community its own ancestor')
    end

    def child_not_more_public_than_parent
      return unless kind == 'hierarchy' && participation != 'open' && source_community && target_community
      return unless privacy_rank(target_community) > privacy_rank(source_community)

      errors.add(:target_community, 'may not be more public than its parent unless participation is open')
    end

    def privacy_rank(community)
      PRIVACY_RANK.fetch(community.privacy.to_s, 0)
    end
  end
end
