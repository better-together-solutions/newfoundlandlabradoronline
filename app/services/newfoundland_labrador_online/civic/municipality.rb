# frozen_string_literal: true

module NewfoundlandLabradorOnline
  module Civic
    # What a municipality page shows for one settlement: its status, its council with the people now in office, and
    # the council's elections. Read only; the loaders write the records.
    class Municipality
      Office = Struct.new(:membership, :person, :role, :title, :seat, :source_url, keyword_init: true) do
        def head? = role == 'legislature_head'
        def deputy? = role == 'legislature_deputy_head'
        def starts_on = membership.starts_at&.to_date
      end

      ROLE_ORDER = %w[legislature_head legislature_deputy_head legislature_member].freeze

      # Settlements that have a municipal council, with their council and detail loaded.
      def self.listed
        councils = municipal_councils
        ids = councils.map { |c| jurisdiction_id(c) }
        settlements = BetterTogether::Geography::Settlement.where(id: ids).index_by(&:id)
        councils.filter_map do |council|
          settlement = settlements[jurisdiction_id(council)]
          new(settlement, council:) if settlement
        end
      end

      def self.municipal_councils
        details = LegislatureDetail.where(level: 'municipal',
                                          jurisdiction_type: BetterTogether::Geography::Settlement.polymorphic_name)
        LegislatureCommunity.joins(:legislature_detail).merge(details).includes(:legislature_detail).to_a
      end

      def self.jurisdiction_id(council) = council.legislature_detail.jurisdiction_id

      def self.for(settlement)
        council = LegislatureCommunity.joins(:legislature_detail)
                                      .find_by(legislature_details: { level: 'municipal',
                                                                      jurisdiction_type: BetterTogether::Geography::Settlement.polymorphic_name,
                                                                      jurisdiction_id: settlement.id })
        new(settlement, council:) if council
      end

      attr_reader :settlement, :council

      def initialize(settlement, council:)
        @settlement = settlement
        @council = council
      end

      def status = settlement.current_status
      def csd_code = settlement.identifier_for('statcan_csd')
      def detail = council.legislature_detail

      def mayor = offices.find(&:head?)
      def deputy_mayor = offices.find(&:deputy?)
      def councillors = offices.reject { |office| office.head? || office.deputy? }

      # People in office today: mayor, deputy mayor, then ward seats in order, then at-large members by name.
      def offices
        @offices ||= current_memberships.map { |membership| office_for(membership) }
                                        .sort_by { |office| sort_key(office) }
      end

      # The council's elections, newest first, each with its contests loaded.
      def elections
        @elections ||= Election.where(community: council).latest_first
                               .includes(contests: [:community_seat,
                                                    { candidacies: { mandate: { membership: :member } } }])
                               .to_a
      end

      def latest_election = elections.first

      def source_url = offices.filter_map(&:source_url).first

      private

      def current_memberships
        BetterTogether::PersonCommunityMembership
          .where(joinable_id: council.id).held_on(Time.current)
          .includes(:role, :mandate, member: Roster::PERSON_PRELOAD).to_a
      end

      def office_for(membership)
        mandate = membership.mandate
        Office.new(membership:, person: membership.member, role: membership.role&.identifier,
                   title: mandate&.title, seat: seats[mandate&.seat_id], source_url: mandate&.source_url)
      end

      def seats
        @seats ||= CommunitySeat.where(community: council).index_by(&:id)
      end

      def sort_key(office)
        [ROLE_ORDER.index(office.role) || ROLE_ORDER.size, office.seat&.position || 999, office.person.name.to_s]
      end
    end
  end
end
