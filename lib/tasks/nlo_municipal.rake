# frozen_string_literal: true

namespace :nlo do
  namespace :municipal do # rubocop:disable Metrics/BlockLength
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

    desc 'Load council election results from db/data/nl_municipal (dry run unless APPLY=1); PACKET= overrides'
    task load_elections: :environment do
      loader = NewfoundlandLabradorOnline::Civic::MunicipalElectionLoader
      path = ENV['PACKET'] ? Pathname.new(ENV['PACKET']) : loader::DEFAULT_PATH
      apply = ENV['APPLY'] == '1'
      result = loader.new(path:, apply:).call
      counts = result.to_h.except(:unlinked, :missing_councils).map { |key, value| "#{key}=#{value}" }.join(' ')
      puts "#{apply ? 'Applied' : 'Dry run'}: #{counts}"
      puts "Elected but not linked to an office: #{result.unlinked.join(', ')}" if result.unlinked.any?
      puts "Missing councils: #{result.missing_councils.join(', ')}" if result.missing_councils.any?
    end

    desc 'Download ward polygons from the City of St. John\'s service into the offline packet (dry unless WRITE=1)'
    task fetch_ward_packet: :environment do
      fetcher = NewfoundlandLabradorOnline::Civic::WardBoundaryFetcher.new(write: ENV['WRITE'] == '1')
      packet = fetcher.call
      verb = ENV['WRITE'] == '1' ? 'Wrote' : 'Dry run, would write'
      puts "#{verb} #{packet['features'].size} wards from #{fetcher.query_url}"
    end

    desc 'Load ward boundaries from db/data/nl_municipal onto council seats (dry run unless APPLY=1); PACKET= overrides'
    task load_ward_boundaries: :environment do
      loader = NewfoundlandLabradorOnline::Civic::WardBoundaryLoader
      path = ENV['PACKET'] ? Pathname.new(ENV['PACKET']) : loader::DEFAULT_PATH
      apply = ENV['APPLY'] == '1'
      result = loader.new(path:, apply:).call
      puts "#{apply ? 'Applied' : 'Dry run'}: created=#{result.created.size} updated=#{result.updated.size} " \
           "unchanged=#{result.unchanged.size}"
      puts "Missing seats (load councils first): #{result.missing_seats.join(', ')}" if result.missing_seats.any?
    end
  end
end
