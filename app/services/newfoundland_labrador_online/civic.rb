# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # Civic membership model helpers shared by the roster, the loaders and the backfill.
  module Civic
    module_function

    # Instants are stored in UTC. Calendar dates convert in Time.zone, which controllers set per request (person, then
    # platform, then app) as for CE events; loaders and jobs have no request, so they run under the platform zone.
    def zone
      Time.zone
    end

    def platform_zone
      BetterTogether::Platform.find_by(host: true)&.time_zone.presence || Rails.application.config.time_zone
    end

    def in_platform_zone(&)
      Time.use_zone(platform_zone, &)
    end

    def local_midnight(date)
      date && zone.local(date.year, date.month, date.day)
    end

    def local_date(time)
      time&.in_time_zone(zone)&.to_date
    end

    def role(identifier)
      BetterTogether::Role.find_by!(identifier:)
    end
  end
end
