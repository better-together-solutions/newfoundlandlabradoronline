# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # Shared behaviour for Community subtypes (STI on the type column): they stay Communities to routes, policies and
  # forms, and use the community role set.
  module CommunitySubtype
    extend ActiveSupport::Concern

    class_methods do
      def model_name
        BetterTogether::Community.model_name
      end

      def policy_class
        BetterTogether::CommunityPolicy
      end
    end

    def default_member_role
      BetterTogether::Role.find_by(resource_type: 'BetterTogether::Community',
                                   identifier: default_member_role_identifier)
    end
  end
end
