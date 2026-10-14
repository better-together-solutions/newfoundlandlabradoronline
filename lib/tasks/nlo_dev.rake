# frozen_string_literal: true

require 'json'
require 'securerandom'

namespace :nlo do
  namespace :dev do
    desc 'Provision local Corner Brook Online publishing fixtures; writes ids and credentials to OUT'
    task cbo_e2e_setup: :environment do
      abort 'Refusing to run in production.' if Rails.env.production?

      out = Rails.root.join(ENV.fetch('OUT', 'tmp/cbo_e2e.json'))
      fixtures = NewfoundlandLabradorOnline::DevPublishingFixtures.new(base_url: ENV.fetch('BASE_URL', 'http://localhost:3005'))
      File.write(out, JSON.pretty_generate(fixtures.provision!))
      File.chmod(0o644, out) # dev-only credentials; the container writes as root
      puts "Wrote #{out} (ids and credentials, local only)"
    end

    desc 'Remove the yt- posts and video blocks a previous publisher run created'
    task cbo_e2e_reset: :environment do
      abort 'Refusing to run in production.' if Rails.env.production?

      NewfoundlandLabradorOnline::DevPublishingFixtures.new(base_url: '').reset_published!
      puts 'Removed yt- posts and blocks'
    end

    desc 'Print the yt- posts the publisher created (JSON), for verifying an end-to-end run'
    task cbo_e2e_report: :environment do
      abort 'Refusing to run in production.' if Rails.env.production?

      puts "CBO_E2E_REPORT #{JSON.generate(NewfoundlandLabradorOnline::DevPublishingReport.new.call)}"
    end
  end
end
