# frozen_string_literal: true

module NewfoundlandLabradorOnline
  module Geography
    # Everything the cover generator (management-tool scripts/district_cover_images.py) needs per provincial
    # district: simplified boundary, source credit, and the colour of the sitting member's current party (so a floor
    # crossing shows), falling back to the party elected in the latest election when the seat is vacant.
    class DistrictCoverInputs
      SIMPLIFY_DEGREES = 0.0005

      def self.call
        new.call
      end

      def call
        ProvincialElectoralDistrict.find_each.filter_map { |district| entry(district) }.to_h
      end

      private

      def entry(district)
        version = district.current_version
        return unless version&.boundary

        [district.name, { id: district.id, slug: district.identifier, kind: kind, color: color_for(district),
                          authority: version.authority, license: version.license, geometry: geometry(version) }]
      end

      def kind
        I18n.t('newfoundland_labrador_online.districts.show.kind', locale: :en)
      end

      def color_for(district)
        party = sitting_party(district) || elected_party(district)
        party ? party.display_color : PoliticalParty::FALLBACK_COLOR
      end

      def sitting_party(district)
        sitting_parties[district.id]
      end

      def sitting_parties
        @sitting_parties ||= Civic::Roster.current_holdings.to_h { |holding| [holding.region_id, holding.party_on] }
      end

      def elected_party(district)
        return unless latest_election

        Candidacy.joins(:electoral_contest, :mandate)
                 .where(electoral_contests: { election_id: latest_election.id, region_id: district.id })
                 .first&.political_party
      end

      def latest_election
        @latest_election ||= Election.where(jurisdiction: 'provincial').order(:held_on).last
      end

      def geometry(version)
        conn = ActiveRecord::Base.connection
        sql = "SELECT ST_AsGeoJSON(ST_SimplifyPreserveTopology(#{conn.quote(version.boundary.as_text)}::geometry, " \
              "#{SIMPLIFY_DEGREES}))"
        JSON.parse(conn.select_value(sql))
      end
    end
  end
end
