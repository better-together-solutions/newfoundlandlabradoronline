# frozen_string_literal: true

namespace :nlo do
  namespace :categories do
    desc 'Seed the video categories used by the Corner Brook Online publisher (idempotent)'
    task seed_video: :environment do
      NewfoundlandLabradorOnline::VideoCategories.seed!
    end
  end
end
