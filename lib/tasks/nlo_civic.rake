# frozen_string_literal: true

namespace :nlo do
  namespace :civic do
    desc 'Seed the generic civic office roles (idempotent, no permissions)'
    task seed_roles: :environment do
      roles = NewfoundlandLabradorOnline::Civic::RoleSeeder.call
      puts "Seeded #{roles.size} civic roles"
    end
  end
end
