# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # Seeds the categories used by timelapse video and sky posts (Shorts, the portrait videos, form their
  # own group). Idempotent and additive: existing categories are never changed; run with `NewfoundlandLabradorOnline::VideoCategoryBuilder.build`
  # or `rake nlo:categories:seed_video`.
  class VideoCategoryBuilder < ::BetterTogether::Builder
    DEFINITIONS = {
      'timelapse' => { en: 'Timelapse', fr: 'Timelapse' },
      'daily-timelapse' => { en: 'Daily Timelapse', fr: 'Timelapse quotidien' },
      'monthly-timelapse' => { en: 'Monthly Timelapse', fr: 'Timelapse mensuel' },
      'annual-timelapse' => { en: 'Annual Timelapse', fr: 'Timelapse annuel' },
      'shorts' => { en: 'Shorts', fr: 'Shorts' },
      'sky' => { en: 'Sky', fr: 'Ciel' }
    }.freeze

    class << self
      # Category identifiers for a video post (kind: daily/monthly/annual, orientation: landscape/portrait).
      def identifiers_for(kind:, orientation:)
        ids = ['timelapse', "#{kind}-timelapse", 'sky']
        ids << 'shorts' if orientation.to_s == 'portrait'
        ids
      end

      def seed_data(platform: ::BetterTogether::Platform.find_by(host: true))
        DEFINITIONS.map { |identifier, names| seed_category(identifier, names, platform) }
      end

      # The categories are protected seed data; they are never cleared by a builder run.
      def clear_existing
        raise NotImplementedError, 'video categories are protected and are not cleared by the builder'
      end

      private

      # Existing categories are returned untouched (names and settings may have been edited since),
      # so a re-run only adds the categories that are missing.
      def seed_category(identifier, names, platform)
        existing = ::BetterTogether::Category.find_by(identifier:, platform:)
        return existing if existing

        category = ::BetterTogether::Category.new(identifier:, platform:, type: '::BetterTogether::Category',
                                                  protected: true, privacy: 'public')
        names.each { |locale, name| Mobility.with_locale(locale) { category.name = name } }
        category.save!
        category
      end
    end
  end
end
