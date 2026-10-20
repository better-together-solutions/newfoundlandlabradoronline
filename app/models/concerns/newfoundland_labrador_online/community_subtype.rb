# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # Shared behaviour for Community subtypes (STI on the type column): they stay Communities to routes, policies and
  # forms, and use the community role set.
  module CommunitySubtype
    extend ActiveSupport::Concern

    # CE's invitation-token authorization finds a policy by class name, so each subtype gets a named one.
    included do
      policy = Class.new(BetterTogether::CommunityPolicy)
      NewfoundlandLabradorOnline.const_set("#{name.demodulize}Policy", policy) unless
        NewfoundlandLabradorOnline.const_defined?("#{name.demodulize}Policy", false)
    end

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
