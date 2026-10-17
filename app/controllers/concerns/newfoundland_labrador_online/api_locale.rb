# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # API requests carry no locale of their own, but CE's web controllers assign I18n.locale on the serving thread
  # without restoring it, so an API write used whatever language the thread last served: the same page got its
  # slug, title and block captions stored under es or fr one time and en the next (ships/ca-algoscotia ended up
  # as "algoscotia" in three locales and the slash slug only in es). Each API request now runs in the default
  # locale, or the one named by an X-Api-Locale header.
  module ApiLocale
    extend ActiveSupport::Concern

    included do
      around_action :with_api_locale, prepend: true
    end

    private

    def with_api_locale(&)
      I18n.with_locale(api_locale, &)
    end

    def api_locale
      requested = request.headers['X-Api-Locale'].to_s.to_sym
      I18n.available_locales.include?(requested) ? requested : I18n.default_locale
    end
  end
end
