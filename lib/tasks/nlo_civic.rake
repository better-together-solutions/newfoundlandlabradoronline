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
  end
end
