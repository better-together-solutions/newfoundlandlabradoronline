# frozen_string_literal: true

# prspec runs before(:suite) once, in the parent, so only the first worker's database is truncated and
# seeded. Give every other worker's database the same starting state as it is forked.
if defined?(ParallelRSpec)
  ParallelRSpec.configure do |config|
    config.after_fork do |worker|
      next if worker == 1

      DatabaseCleaner.clean_with(:truncation, except: %w[spatial_ref_sys])
      load BetterTogether::Engine.root.join('db', 'seeds.rb')
    end
  end
end
