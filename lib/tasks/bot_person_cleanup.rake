# frozen_string_literal: true

require 'json'

namespace :maintenance do
  desc 'Dry-run or execute callback-driven cleanup for explicit bot person IDs'
  task cleanup_bot_people: :environment do
    person_ids = ENV.fetch('PERSON_IDS', '').split(',').map(&:strip).reject(&:empty?)
    preserve_person_ids = ENV.fetch('PRESERVE_PERSON_IDS', '').split(',').map(&:strip).reject(&:empty?)
    write_enable = ActiveModel::Type::Boolean.new.cast(ENV.fetch('WRITE_ENABLE', 'false'))

    abort 'PERSON_IDS is required (comma-separated UUIDs).' if person_ids.empty?

    result = BetterTogether::BotPersonCleanupService.new(
      person_ids:,
      preserve_person_ids:,
      write_enable:,
      logger: Rails.logger
    ).call

    puts JSON.pretty_generate(result)
  rescue BetterTogether::BotPersonCleanupService::CleanupError => e
    warn e.message
    exit 1
  end
end
