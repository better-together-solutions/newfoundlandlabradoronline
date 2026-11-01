# frozen_string_literal: true

namespace :nlo do
  namespace :municipal do
    desc 'Load municipal councils and officials from db/data/nl_municipal (dry run unless APPLY=1); PACKET= overrides'
    task load_councils: :environment do
      loader = NewfoundlandLabradorOnline::Civic::MunicipalRosterLoader
      path = ENV['PACKET'] ? Pathname.new(ENV['PACKET']) : loader::DEFAULT_PATH
      apply = ENV['APPLY'] == '1'
      result = loader.new(path:, apply:).call
      counts = result.to_h.except(:missing_settlements).map { |key, value| "#{key}=#{value}" }.join(' ')
      puts "#{apply ? 'Applied' : 'Dry run'}: #{counts}"
      puts "Missing settlements: #{result.missing_settlements.join(', ')}" if result.missing_settlements.any?
    end
  end
end
