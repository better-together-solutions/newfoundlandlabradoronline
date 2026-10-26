# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # Names the role tabs for Community subtypes, which CE's resource label lookup does not know.
  module RoleResourceTypeLabels
    def role_resource_type_label(resource_type)
      return super unless SubtypeResourceTypes::TYPES.include?(resource_type)

      I18n.t("newfoundland_labrador_online.community_subtypes.#{resource_type.demodulize.underscore}")
    end
  end
end
