# frozen_string_literal: true

module NewfoundlandLabradorOnline
  module Civic
    # A person's membership of a party, read from the party community membership and its mandate.
    class PartyHolding
      def self.model_name
        ActiveModel::Name.new(self, nil, 'NewfoundlandLabradorOnline::PartyMembership')
      end

      delegate :model_name, to: :class

      attr_reader :membership, :political_party

      def person_id = membership.member_id

      def initialize(membership:, political_party:)
        @membership = membership
        @political_party = political_party
      end

      def person = membership.member
      def start_reason = membership.mandate&.start_reason
      def end_reason = membership.mandate&.end_reason
      def source_url = membership.mandate&.source_url
      def started_on = Civic.local_date(membership.starts_at)
      def ended_on = Civic.local_date(membership.ends_at)
      def to_param = membership.id
      def to_key = [membership.id]
      def to_model = self
    end
  end
end
