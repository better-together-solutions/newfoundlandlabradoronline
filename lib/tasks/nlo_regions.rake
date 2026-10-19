# frozen_string_literal: true

namespace :nlo do
  namespace :regions do
    desc 'Load the 40 provincial electoral districts (2015 map) from db/data/nl_regions; idempotent'
    task load_provincial_districts: :environment do
      result = NewfoundlandLabradorOnline::Geography::ProvincialDistrictLoader.new.call
      puts "created=#{result.created.size} updated=#{result.updated.size} unchanged=#{result.unchanged.size}"
    end
  end
end
