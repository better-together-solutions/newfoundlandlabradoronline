# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # Community-to-community associations: parents, children, peers and who may join under them.
  module Associable
    extend ActiveSupport::Concern

    included do
      has_many :outgoing_associations, class_name: 'NewfoundlandLabradorOnline::CommunityAssociation',
                                       foreign_key: :source_community_id, inverse_of: :source_community,
                                       dependent: :destroy
      has_many :incoming_associations, class_name: 'NewfoundlandLabradorOnline::CommunityAssociation',
                                       foreign_key: :target_community_id, inverse_of: :target_community,
                                       dependent: :destroy
    end

    def parents(on: Time.current)
      related(incoming_associations.hierarchy.active_on(on), :source_community_id)
    end

    def children(on: Time.current)
      related(outgoing_associations.hierarchy.active_on(on), :target_community_id)
    end

    def peers(on: Time.current)
      ids = outgoing_associations.where(kind: 'peer').active_on(on).pluck(:target_community_id) +
            incoming_associations.where(kind: 'peer').active_on(on).pluck(:source_community_id)
      BetterTogether::Community.where(id: ids.uniq)
    end

    def descendant_ids(on: nil)
      tree_ids(:source_community_id, :target_community_id, on)
    end

    def ancestor_ids(on: nil)
      tree_ids(:target_community_id, :source_community_id, on)
    end

    def descendants(on: nil)
      BetterTogether::Community.where(id: descendant_ids(on:))
    end

    def ancestors(on: nil)
      BetterTogether::Community.where(id: ancestor_ids(on:))
    end

    def cascading_associations
      outgoing_associations.where(cascade_end: true).includes(:target_community).active_on(Time.current)
    end

    # :member (qualifies by membership), :invited (qualifies by invitation or appointment), :invitation_required,
    # :open (no association restricts joining) or :ineligible.
    def eligibility_for(person, on: Time.current, invited: false)
      gates = incoming_associations.active_on(on).where(participation: %w[members_only members_and_invited]).to_a
      return :open if gates.empty?

      required, alternatives = gates.partition { |gate| gate.participation == 'members_only' }
      return :ineligible unless required_met?(required, person, on)

      alternatives_met = alternatives.empty? || any_membership?(alternatives, person, on)
      return :member if alternatives_met

      invited ? :invited : :invitation_required
    end

    private

    def required_met?(required, person, on)
      grouped(required).all? { |group| any_membership?(group, person, on) }
    end

    def grouped(associations)
      associations.group_by { |gate| gate.eligibility_group || gate.id }.values
    end

    def any_membership?(gates, person, on)
      BetterTogether::PersonCommunityMembership.where(member_id: person.id, status: 'active',
                                                      joinable_id: gates.map(&:source_community_id))
                                               .held_on(on.to_time).exists?
    end

    def related(scope, column)
      BetterTogether::Community.where(id: scope.select(column))
    end

    def tree_ids(from, to, on)
      sql = <<~SQL.squish
        WITH RECURSIVE tree(id) AS (
          SELECT #{to} FROM community_associations WHERE #{from} = :id AND kind = 'hierarchy' #{window('community_associations', on)}
          UNION
          SELECT a.#{to} FROM community_associations a JOIN tree ON a.#{from} = tree.id
          WHERE a.kind = 'hierarchy' #{window('a', on)}
        ) SELECT id FROM tree
      SQL
      self.class.connection.select_values(self.class.sanitize_sql([sql, { id:, on: on&.to_date }]))
    end

    def window(table, on)
      return '' unless on

      "AND (#{table}.starts_on IS NULL OR #{table}.starts_on <= :on) " \
        "AND (#{table}.ends_on IS NULL OR #{table}.ends_on >= :on)"
    end
  end
end
