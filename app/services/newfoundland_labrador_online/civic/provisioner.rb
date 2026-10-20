# frozen_string_literal: true

module NewfoundlandLabradorOnline
  module Civic
    # Creates the communities the civic model hangs on: one legislature per province that has elections, and one
    # party community per political party. Idempotent; seeds the generic roles first.
    class Provisioner
      LEGISLATURES = {
        'nl' => { name: 'House of Assembly of Newfoundland and Labrador', member_title: 'MHA', seat_count: 40 }
      }.freeze

      def self.call
        new.call
      end

      def call
        RoleSeeder.call
        { legislatures: provision_legislatures, parties: provision_parties }
      end

      def legislature_for(state)
        state ||= Province.state_for('nl')
        LegislatureCommunity.joins(:legislature_detail)
                            .find_by(legislature_details: { jurisdiction_type: state.class.polymorphic_name,
                                                            jurisdiction_id: state.id })
      end

      def legislature!(state)
        legislature_for(state) || create_legislature(state || Province.state_for('nl'))
      end

      def provision_party(party)
        return party.community if party.community

        identifier = ['party', party.jurisdiction, party.state && Province.code_for(party.state), party.identifier]
        party.update!(community: PartyCommunity.create!(community_attributes(identifier.compact.join('-'),
                                                                             party.name)))
        party.community
      end

      private

      def provision_legislatures
        provinces.map { |state| legislature!(state) }
      end

      def provinces
        elections = Election.where(jurisdiction: 'provincial')
        states = BetterTogether::Geography::State.where(id: elections.select(:state_id)).to_a
        states << Province.state_for('nl') if elections.exists?(state_id: nil)
        states.uniq
      end

      def create_legislature(state)
        code = Province.code_for(state)
        defaults = LEGISLATURES.fetch(code, { name: "Legislature of #{state.name}" })
        community = LegislatureCommunity.create!(community_attributes("provincial-legislature-#{code}",
                                                                      defaults[:name]))
        community.create_legislature_detail!(level: 'provincial', jurisdiction: state,
                                             seat_count: defaults[:seat_count], member_title: defaults[:member_title])
        community
      end

      def provision_parties
        PoliticalParty.where(community_id: nil).find_each.map { |party| provision_party(party) && party }
      end

      def community_attributes(identifier, name)
        { identifier:, name:, privacy: 'public', host: false, protected: false, requires_invitation: true }
      end
    end
  end
end
