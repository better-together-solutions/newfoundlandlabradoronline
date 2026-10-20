# frozen_string_literal: true

module NewfoundlandLabradorOnline
  module Civic
    # The single read path for who sits where and for which party. Pages ask it instead of querying memberships.
    module Roster
      SEAT_TYPE = 'BetterTogether::Geography::Region'
      PERSON_PRELOAD = [:string_translations, :slugs, { profile_image_attachment: :blob }].freeze

      # One person's unbroken stretch in a seat: latest term first, dates spanning all of them.
      Run = Struct.new(:holdings) do
        def latest = holdings.first
        def person = latest.person
        def political_party = latest.party_on
        def started_on = holdings.last.started_on
        def ended_on = latest.ended_on
        def terms = holdings.size
      end

      module_function

      # Sitting members of the legislatures, optionally limited to some districts.
      def current_holdings(region_ids: nil)
        build(seat_memberships(region_ids).held_on(Time.current))
      end

      # Sitting (current: true) or former members of one legislature, by district name.
      def legislature_holdings(legislature, current: true)
        scope = seat_memberships.where(joinable_id: legislature.id)
        scope = current ? scope.held_on(Time.current) : scope.former
        build(scope, order: :desc).sort_by { |holding| [holding.region.name, -holding.membership.starts_at.to_i] }
      end

      # Every term in one district, latest first.
      def district_history(region)
        build(seat_memberships([region.id]), order: :desc)
      end

      # Consecutive terms of one person in a seat folded into one entry (holdings latest first).
      def runs(holdings)
        holdings.slice_when { |a, b| a.person_id != b.person_id }.map { |group| Run.new(group) }
      end

      # Terms of the given people grouped by person id, latest first.
      def holdings_by_person(person_ids)
        build(seat_memberships.where(member_id: person_ids), order: :desc).group_by(&:person_id)
      end

      # Sitting members per party id (a member counts for the party they sit for now).
      def current_seats_by_party_id
        current_holdings.group_by { |holding| holding.party_on&.id }.transform_values(&:size)
      end

      # Members elected per election and party label, from the mandates conferred by each election's candidacies.
      def seats_by_election_and_party(election_ids)
        Candidacy.joins(:electoral_contest, :mandate).where(electoral_contests: { election_id: election_ids })
                 .group('electoral_contests.election_id', :party_name).count
      end

      # A party's memberships, newest first.
      def party_holdings(party)
        return [] unless party.community_id

        memberships = party_memberships(party.community_id).includes(:mandate, member: PERSON_PRELOAD)
        memberships.order(starts_at: :desc).map { |m| PartyHolding.new(membership: m, political_party: party) }
      end

      # The party membership a person holds on a date (a Date or Time), or nil.
      def party_membership_on(person, date)
        time = date.is_a?(Date) ? Civic.local_midnight(date) : date
        party_memberships(PartyCommunity.select(:id)).where(member_id: person.id).held_on(time)
                                                     .order(:starts_at).last
      end

      def seat_memberships(region_ids = nil)
        scope = BetterTogether::PersonCommunityMembership
                .where(joinable_id: LegislatureCommunity.select(:id))
                .joins(:mandate).where(membership_mandates: { seat_type: SEAT_TYPE })
        region_ids ? scope.where(membership_mandates: { seat_id: region_ids }) : scope
      end

      def party_memberships(community_ids)
        BetterTogether::PersonCommunityMembership.where(joinable_id: community_ids)
      end

      def build(scope, order: :asc)
        memberships = scope.includes(:mandate, member: PERSON_PRELOAD).order(starts_at: order).to_a
        return [] if memberships.empty?

        lookups = Lookups.new(memberships)
        memberships.map do |m|
          Holding.new(membership: m, region: lookups.region(m), candidacy: lookups.candidacy(m),
                      party_rows: lookups.party_rows(m.member_id))
        end
      end

      # Batched loads for a set of memberships: seats, candidacies and each person's dated party memberships.
      class Lookups
        def initialize(memberships)
          @memberships = memberships
        end

        def region(membership)
          regions.fetch(membership.mandate.seat_id)
        end

        def candidacy(membership)
          candidacies[membership.mandate.conferred_by_id]
        end

        def party_rows(member_id)
          party_rows_by_member.fetch(member_id, [])
        end

        private

        def mandates = @memberships.map(&:mandate)

        def regions
          @regions ||= BetterTogether::Geography::Region
                       .where(id: mandates.map(&:seat_id)).includes(:string_translations, :slugs).index_by(&:id)
        end

        def candidacies
          @candidacies ||= Candidacy.where(id: mandates.map(&:conferred_by_id))
                                    .includes(:political_party, electoral_contest: :election).index_by(&:id)
        end

        def party_rows_by_member
          @party_rows_by_member ||= begin
            parties = PoliticalParty.where.not(community_id: nil).index_by(&:community_id)
            rows = Roster.party_memberships(parties.keys).where(member_id: @memberships.map(&:member_id).uniq)
            rows.map { |m| PartyHolding.new(membership: m, political_party: parties[m.joinable_id]) }
                .group_by(&:person_id)
          end
        end
      end
    end
  end
end
