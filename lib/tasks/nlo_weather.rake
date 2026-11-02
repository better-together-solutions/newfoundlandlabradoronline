# frozen_string_literal: true

namespace :nlo do
  namespace :weather do
    desc 'Create the weather sources and locations in config/weather/sources.yml; dry run unless APPLY=1'
    task load_locations: :environment do
      apply = ENV['APPLY'] == '1'
      result = NewfoundlandLabradorOnline::Weather::LocationLoader.new(apply:).call
      puts "#{apply ? 'Applied' : 'Dry run (set APPLY=1 to write)'}: created=#{result.created.size} " \
           "existing=#{result.existing.size}"
      puts "Created: #{result.created.join(', ')}" if result.created.any?
      puts "No settlement for: #{result.missing_settlements.join(', ')}" if result.missing_settlements.any?
    end
  end
end
