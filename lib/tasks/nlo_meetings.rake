# frozen_string_literal: true

namespace :nlo do
  namespace :meetings do
    desc 'Import public meetings (SOURCE=cornerbrook); dry run unless APPLY=1; FROM= TO= dates'
    task import: :environment do
      key = ENV.fetch('SOURCE')
      config = YAML.load_file(Rails.root.join('config/meetings/sources.yml')).fetch(key)
      source = NewfoundlandLabradorOnline::Meetings::EscribeSource.new(config)
      from = Date.parse(ENV['FROM'] || "#{config.fetch('first_year')}-01-01")
      to = Date.parse(ENV['TO'] || "#{Time.zone.today.year + 1}-12-31")
      meetings = source.fetch(from:, to:)
      apply = ENV['APPLY'] == '1'
      result = NewfoundlandLabradorOnline::Meetings::Importer.new(source_key: key, config:, meetings:, apply:).call
      puts "#{apply ? 'Applied' : 'Dry run'}: fetched=#{meetings.size} #{result.counts.map do |k, v|
        "#{k}=#{v}"
      end.join(' ')}"
      puts "Missing council: #{result.missing_bodies.join(', ')}" if result.missing_bodies.any?
    end
  end
end
