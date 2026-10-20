# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # Civic membership model helpers shared by the roster, the loaders and the backfill.
  module Civic
    module_function

    def zone
      ActiveSupport::TimeZone[NewfoundlandLabradorOnline::MembershipTimeBox::TIME_ZONE]
    end

    def local_midnight(date)
      date && zone.local(date.year, date.month, date.day)
    end

    def local_date(time)
      time&.in_time_zone(zone)&.to_date
    end

    def role(identifier)
      BetterTogether::Role.find_by!(identifier:, resource_type: RoleSeeder::RESOURCE_TYPE)
    end
  end
end
