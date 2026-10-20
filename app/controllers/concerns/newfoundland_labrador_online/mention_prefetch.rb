# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # Looks up which of a page's people the viewer may see in one query, for NewfoundlandLabradorOnline::MentionVisibility.
  module MentionPrefetch
    private

    def prefetch_mention_visibility(people)
      ids = people.compact.map(&:id).uniq
      @mention_visible_ids = policy_scope(BetterTogether::Person).where(id: ids).pluck(:id).to_set
    end
  end
end
