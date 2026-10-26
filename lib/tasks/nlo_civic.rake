# frozen_string_literal: true

namespace :nlo do
  namespace :civic do
    desc 'Seed the generic civic office roles (idempotent, no permissions)'
    task seed_roles: :environment do
      roles = NewfoundlandLabradorOnline::Civic::RoleSeeder.call
      puts "Seeded #{roles.size} civic roles"
    end

    desc 'Create the legislature and party communities and seed roles (idempotent)'
    task provision: :environment do
      result = NewfoundlandLabradorOnline::Civic::Provisioner.call
      puts "Provisioned #{result[:legislatures].size} legislatures, #{result[:parties].size} new parties"
    end

    desc 'Convert elected terms and party memberships to memberships (dry run unless WRITE=1)'
    task backfill: :environment do
      result = NewfoundlandLabradorOnline::Civic::Backfill.call(write: ENV['WRITE'] == '1')
      puts result.to_h.except(:errors)
      puts result.errors
      abort "#{result.errors.size} records failed" if result.errors.any?
    end

    desc 'Compare the civic model with the elected terms and party memberships; fails on any difference'
    task parity: :environment do
      differences = NewfoundlandLabradorOnline::Civic::ParityReport.call
      puts differences.empty? ? 'Parity: no differences' : differences
      abort 'Parity failed' if differences.any?
    end
  end
end
