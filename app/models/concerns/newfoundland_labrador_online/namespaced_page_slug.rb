# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # Keeps forward slashes in page slugs. CE sets Page.parameterize_slug to false so a slug like
  # "ships/mt-explora-iii" is accepted, but two steps still flatten it: FriendlyId's slug normalization
  # (String#parameterize on the whole value) and Identifier#generate_identifier, which builds the identifier
  # from slug.parameterize and then writes it back to the slug. Each path segment is parameterized on its own
  # instead, and a namespaced slug becomes its own identifier, so namespaced pages (ships/*) keep their slash
  # and the catch-all page route finds them.
  module NamespacedPageSlug
    def normalize_friendly_id(value)
      value.to_s.split('/').map(&:parameterize).reject(&:blank?).join('/')
    end

    protected

    def generate_identifier
      return super unless identifier.blank? && slug.to_s.include?('/')

      self.identifier = normalize_friendly_id(slug)
    end
  end
end
