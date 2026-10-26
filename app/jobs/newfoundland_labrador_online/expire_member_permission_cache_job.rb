# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # Run when a time-boxed membership starts or ends so the member's cached roles and permissions are rebuilt.
  class ExpireMemberPermissionCacheJob < ApplicationJob
    queue_as :default

    def perform(member_id)
      BetterTogether::Person.find_by(id: member_id)&.expire_permission_cache!
    end
  end
end
