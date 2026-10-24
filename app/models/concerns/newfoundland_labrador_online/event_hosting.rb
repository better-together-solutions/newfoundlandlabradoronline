# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # API input naming the community that hosts an event. Setting it replaces the event's hosts, so the creator is
  # not added as a host (CE's set_host only fills in the creator when no host was given). Works on create and update.
  module EventHosting
    extend ActiveSupport::Concern

    COMMUNITY = 'BetterTogether::Community'

    included do
      validate :host_community_must_exist
    end

    def host_community_id
      event_hosts.reject(&:marked_for_destruction?).find { |host| host.host_type == COMMUNITY }&.host_id
    end

    def host_community_id=(value)
      @host_community_error = nil
      return if value.present? && value.to_s == host_community_id.to_s

      community = value.present? && COMMUNITY.constantize.find_by(id: value)
      if community
        event_hosts.each(&:mark_for_destruction)
        event_hosts.build(host: community)
      else
        @host_community_error = true
      end
    end

    private

    def host_community_must_exist
      errors.add(:host_community_id, :invalid) if @host_community_error
    end
  end
end
