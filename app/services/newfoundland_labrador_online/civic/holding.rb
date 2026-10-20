# frozen_string_literal: true

module NewfoundlandLabradorOnline
  module Civic
    # One member's term in a district seat, read from a legislature membership and its mandate. It answers the same
    # questions the pages asked of an elected term: who, where, when, under which party.
    class Holding
      def self.model_name
        ActiveModel::Name.new(self, nil, 'NewfoundlandLabradorOnline::ElectedTerm')
      end

      delegate :model_name, to: :class

      attr_reader :membership, :mandate, :region, :candidacy, :party_rows

      def initialize(membership:, region:, candidacy:, party_rows: [])
        @membership = membership
        @mandate = membership.mandate
        @region = region
        @candidacy = candidacy
        @party_rows = party_rows
      end

      def person_id = membership.member_id
      def person = membership.member
      def election = candidacy&.electoral_contest&.election
      def political_party = candidacy&.political_party
      def party_name = candidacy&.party_name
      def end_reason = mandate.end_reason
      def started_on = Civic.local_date(membership.starts_at)
      def ended_on = Civic.local_date(membership.ends_at)
      def current? = ended_on.nil?
      def region_id = region.id
      def to_param = membership.id
      def to_key = [membership.id]
      def to_model = self

      # The party the member sat for on a date: the dated party membership, else the party run under.
      def party_on(date = Time.zone.today)
        held = party_rows.select { |row| row.started_on <= date && (row.ended_on.nil? || row.ended_on > date) }
        held.max_by(&:started_on)&.political_party || political_party
      end
    end
  end
end
