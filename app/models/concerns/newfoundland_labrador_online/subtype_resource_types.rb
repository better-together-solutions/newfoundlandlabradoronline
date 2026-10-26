# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # Lets a Role or ResourcePermission be scoped to one Community subtype. CE only accepts its own resource classes, so
  # a role scoped to a subtype is never offered for ordinary communities (CE's pickers match resource_type exactly).
  module SubtypeResourceTypes
    TYPES = %w[
      NewfoundlandLabradorOnline::LegislatureCommunity NewfoundlandLabradorOnline::ExecutiveCommunity
      NewfoundlandLabradorOnline::PartyCommunity NewfoundlandLabradorOnline::DepartmentCommunity
      NewfoundlandLabradorOnline::CommitteeCommunity NewfoundlandLabradorOnline::OrganizationCommunity
    ].freeze

    def self.allowed
      BetterTogether::Resourceful::RESOURCE_CLASSES + TYPES
    end

    def self.wire!
      %w[role resource_permission roles_helper].each { |file| require_dependency "better_together/#{file}" }
      BetterTogether::Role.prepend(self)
      BetterTogether::ResourcePermission.prepend(self)
      BetterTogether::RolesHelper.prepend(RoleResourceTypeLabels)
    end

    def self.prepended(base)
      base.validators_on(:resource_type).grep(ActiveModel::Validations::InclusionValidator).each do |validator|
        base._validators[:resource_type].delete(validator)
        base.skip_callback(:validate, validator)
      end
      base.validates :resource_type, inclusion: { in: ->(_record) { allowed } }
    end
  end
end
