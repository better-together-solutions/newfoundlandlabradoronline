# frozen_string_literal: true

module NewfoundlandLabradorOnline
  module Civic
    # Seeds the generic office roles used by civic communities. They carry no permissions, so they are inert for
    # access control; they only say what a person is in a body. Safe to run repeatedly.
    class RoleSeeder
      RESOURCE_TYPE = 'BetterTogether::Community'

      ROLES = {
        'legislature_member' => { en: 'Member of the legislature', es: 'Miembro de la legislatura',
                                  fr: 'Membre de la législature' },
        'legislature_speaker' => { en: 'Speaker', es: 'Presidente de la cámara', fr: "Président de l'assemblée" },
        'legislature_deputy_speaker' => { en: 'Deputy Speaker', es: 'Vicepresidente de la cámara',
                                          fr: "Vice-président de l'assemblée" },
        'official_opposition_leader' => { en: 'Leader of the Official Opposition', es: 'Líder de la oposición oficial',
                                          fr: "Chef de l'opposition officielle" },
        'executive_head' => { en: 'Head of the executive', es: 'Jefe del ejecutivo', fr: "Chef de l'exécutif" },
        'executive_member' => { en: 'Member of the executive', es: 'Miembro del ejecutivo',
                                fr: "Membre de l'exécutif" },
        'party_member' => { en: 'Party member', es: 'Miembro del partido', fr: 'Membre du parti' },
        'party_leader' => { en: 'Party leader', es: 'Líder del partido', fr: 'Chef du parti' },
        'department_head' => { en: 'Head of department', es: 'Jefe de departamento',
                               fr: 'Responsable du département' },
        'director' => { en: 'Director', es: 'Director', fr: 'Administrateur' },
        'chair' => { en: 'Chair', es: 'Presidente', fr: 'Président' },
        'treasurer' => { en: 'Treasurer', es: 'Tesorero', fr: 'Trésorier' },
        'organisation_member' => { en: 'Member of the organisation', es: 'Miembro de la organización',
                                   fr: "Membre de l'organisation" }
      }.freeze

      def self.call
        new.call
      end

      def call
        ROLES.each_with_index.map { |(identifier, names), index| seed(identifier, names, index) }
      end

      private

      def seed(identifier, names, index)
        role = BetterTogether::Role.find_or_initialize_by(identifier:)
        role.resource_type = RESOURCE_TYPE
        role.protected = false if role.new_record?
        names.each { |locale, name| Mobility.with_locale(locale) { role.name = name } }
        role.position = 100 + index if role.new_record?
        role.save!
        role
      end
    end
  end
end
