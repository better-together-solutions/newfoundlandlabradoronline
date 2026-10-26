# frozen_string_literal: true

module NewfoundlandLabradorOnline
  module Civic
    # Seeds the office roles used by civic communities. Each is scoped to the one Community subtype it belongs to
    # (its resource_type), so ordinary communities never offer them. They carry no permissions, so they are inert for
    # access control; they only say what a person is in a body. Safe to run repeatedly.
    class RoleSeeder
      # Subtype class name (under NewfoundlandLabradorOnline) => role identifier => names.
      ROLES = {
        'LegislatureCommunity' => {
          'legislature_member' => { en: 'Member of the legislature', es: 'Miembro de la legislatura',
                                    fr: 'Membre de la législature' },
          'legislature_speaker' => { en: 'Speaker', es: 'Presidente de la cámara', fr: "Président de l'assemblée" },
          'legislature_deputy_speaker' => { en: 'Deputy Speaker', es: 'Vicepresidente de la cámara',
                                            fr: "Vice-président de l'assemblée" },
          'official_opposition_leader' => { en: 'Leader of the Official Opposition',
                                            es: 'Líder de la oposición oficial',
                                            fr: "Chef de l'opposition officielle" }
        },
        'ExecutiveCommunity' => {
          'executive_head' => { en: 'Head of the executive', es: 'Jefe del ejecutivo', fr: "Chef de l'exécutif" },
          'executive_member' => { en: 'Member of the executive', es: 'Miembro del ejecutivo',
                                  fr: "Membre de l'exécutif" }
        },
        'PartyCommunity' => {
          'party_member' => { en: 'Party member', es: 'Miembro del partido', fr: 'Membre du parti' },
          'party_leader' => { en: 'Party leader', es: 'Líder del partido', fr: 'Chef du parti' }
        },
        'DepartmentCommunity' => {
          'department_head' => { en: 'Head of department', es: 'Jefe de departamento',
                                 fr: 'Responsable du département' }
        },
        'CommitteeCommunity' => {
          'committee_chair' => { en: 'Committee chair', es: 'Presidente del comité', fr: 'Président du comité' }
        },
        'OrganizationCommunity' => {
          'director' => { en: 'Director', es: 'Director', fr: 'Administrateur' },
          'chair' => { en: 'Chair', es: 'Presidente', fr: 'Président' },
          'treasurer' => { en: 'Treasurer', es: 'Tesorero', fr: 'Trésorier' },
          'organisation_member' => { en: 'Member of the organisation', es: 'Miembro de la organización',
                                     fr: "Membre de l'organisation" }
        }
      }.freeze

      def self.call
        new.call
      end

      def call
        ROLES.flat_map do |subtype, roles|
          roles.map { |identifier, names| seed(identifier, "NewfoundlandLabradorOnline::#{subtype}", names) }
        end
      end

      private

      def seed(identifier, resource_type, names)
        role = BetterTogether::Role.find_or_initialize_by(identifier:)
        role.position = nil if role.resource_type != resource_type
        role.resource_type = resource_type
        role.protected = false if role.new_record?
        names.each { |locale, name| Mobility.with_locale(locale) { role.name = name } }
        role.save!
        role
      end
    end
  end
end
