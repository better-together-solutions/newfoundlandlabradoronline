# frozen_string_literal: true

namespace :nlo do
  namespace :electoral do
    desc 'Seed the provincial electoral data packet on an installed platform (idempotent); see docs/regions.md'
    task seed: :environment do
      NewfoundlandLabradorOnline::ElectoralSeed.call.each { |step, summary| puts "#{step}: #{summary}" }
    rescue NewfoundlandLabradorOnline::ElectoralSeed::MissingPrerequisite => e
      abort e.message
    end
  end
end
