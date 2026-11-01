# frozen_string_literal: true

module NewfoundlandLabradorOnline
  module Civic
    # The council (or local service district committee) community for one settlement, with its named seats. Idempotent:
    # matched on the settlement, so a rerun fills in what is missing and never duplicates.
    class MunicipalCouncil
      def self.call(...)
        new(...).call
      end

      # seats: [{ 'name' => 'Ward 1', 'kind' => 'at_large' }]
      # detail: body_kind (council or lsd_committee), seat_count, member_title
      def initialize(settlement:, name:, seats: [], **detail)
        @settlement = settlement
        @name = name
        @seats = seats
        @detail = { body_kind: 'council', member_title: 'Councillor' }.merge(detail.compact)
      end

      def call
        community = existing || create_community
        detail = community.legislature_detail || community.build_legislature_detail(level: 'municipal',
                                                                                    jurisdiction: @settlement)
        detail.update!(@detail.slice(:body_kind, :seat_count, :member_title))
        @seats.each { |seat| ensure_seat(community, seat) }
        community
      end

      private

      def existing
        LegislatureCommunity.joins(:legislature_detail)
                            .find_by(legislature_details: { level: 'municipal',
                                                            jurisdiction_type: @settlement.class.polymorphic_name,
                                                            jurisdiction_id: @settlement.id })
      end

      def create_community
        LegislatureCommunity.create!(identifier: "municipal-council-#{@settlement.identifier}", name: @name,
                                     privacy: 'public', host: false, protected: false, requires_invitation: true)
      end

      def ensure_seat(community, seat)
        record = CommunitySeat.find_or_initialize_by(community:, name: seat.fetch('name'))
        record.update!(kind: seat.fetch('kind', 'at_large'), position: seat.fetch('position', 0))
      end
    end
  end
end
