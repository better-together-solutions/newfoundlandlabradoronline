# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # Seeds the categories used by timelapse video posts (Shorts, the portrait videos, form their
  # own group). Idempotent; run with `NewfoundlandLabradorOnline::VideoCategoryBuilder.build`
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

      def seed_category(identifier, names, platform)
        category = ::BetterTogether::Category.find_or_initialize_by(identifier:, platform:)
        category.type ||= '::BetterTogether::Category'
        category.protected = true
        category.privacy = 'public'
        names.each { |locale, name| Mobility.with_locale(locale) { category.name = name } }
        category.save!
        category
      end
    end
  end
end
