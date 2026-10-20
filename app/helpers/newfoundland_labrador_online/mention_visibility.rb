# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # Uses the page's prefetched visible person ids for mention links, falling back to CE's per-person policy check.
  module MentionVisibility
    def mention_profile_path(person)
      return super unless person && @mention_visible_ids&.include?(person.id)

      person_path(person)
    end
  end
end
