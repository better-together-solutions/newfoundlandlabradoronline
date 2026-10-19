# frozen_string_literal: true

Rails.application.routes.draw do
  get 'healthcheck', to: 'healthcheck#index'
  get 'live/:slug.jpg', to: 'newfoundland_labrador_online/live_images#show',
                        constraints: { slug: /[a-z-]+/ }, format: false
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html

  scope ':locale',
        locale: /#{I18n.available_locales.join('|')}/ do
    authenticated :user do # rubocop:todo Lint/EmptyBlock
    end

    resources :districts, only: %i[index show], controller: 'newfoundland_labrador_online/districts',
                          as: :newfoundland_labrador_online_districts
    get 'locations/available', to: 'newfoundland_labrador_online/locations#available',
                               as: :newfoundland_labrador_online_available_locations
  end

  root to: redirect("/#{I18n.default_locale}")
  mount BetterTogether::Engine => '/'
end
