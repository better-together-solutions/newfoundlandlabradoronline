# frozen_string_literal: true

namespace :nlo do
  namespace :regions do
    desc 'Load the 40 provincial electoral districts (2015 map) from db/data/nl_regions; idempotent'
    task load_provincial_districts: :environment do
      result = NewfoundlandLabradorOnline::Geography::ProvincialDistrictLoader.new.call
      puts "created=#{result.created.size} updated=#{result.updated.size} unchanged=#{result.unchanged.size}"
    end

    desc 'Load provincial parties (colours, logos) from db/data/nl_regions, before the elections; idempotent'
    task load_political_parties: :environment do
      result = NewfoundlandLabradorOnline::Geography::PoliticalPartyLoader.new.call
      puts result.to_h.map { |key, value| "#{key}=#{value}" }.join(' ')
    end

    desc 'Load provincial general-election results and elected members (2015-2025) from db/data/nl_regions; idempotent'
    task load_provincial_elections: :environment do
      result = NewfoundlandLabradorOnline::Geography::ProvincialElectionLoader.new.call
      puts result.to_h.except(:missing_districts).map { |key, value| "#{key}=#{value}" }.join(' ')
      puts "missing districts: #{result.missing_districts.uniq.join(', ')}" if result.missing_districts.any?
    end
  end
end
