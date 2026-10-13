# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # Categories for timelapse video posts. Shorts (portrait videos) form their own group.
  module VideoCategories
    DEFINITIONS = {
      'timelapse' => { en: 'Timelapse', fr: 'Timelapse' },
      'daily-timelapse' => { en: 'Daily Timelapse', fr: 'Timelapse quotidien' },
      'monthly-timelapse' => { en: 'Monthly Timelapse', fr: 'Timelapse mensuel' },
      'annual-timelapse' => { en: 'Annual Timelapse', fr: 'Timelapse annuel' },
      'shorts' => { en: 'Shorts', fr: 'Shorts' }
    }.freeze

    # identifiers for a publisher payload (kind: daily/monthly/annual, orientation: landscape/portrait)
    def self.identifiers_for(kind:, orientation:)
      ids = ['timelapse', "#{kind}-timelapse"]
      ids << 'shorts' if orientation.to_s == 'portrait'
      ids
    end

    def self.seed!(platform: ::BetterTogether::Platform.find_by(host: true))
      DEFINITIONS.map do |identifier, names|
        category = ::BetterTogether::Category.find_or_initialize_by(identifier:, platform:)
        category.type ||= '::BetterTogether::Category'
        category.protected = true
        names.each { |locale, name| Mobility.with_locale(locale) { category.name = name } }
        category.privacy = 'public'
        category.save!
        category
      end
    end
  end
end
