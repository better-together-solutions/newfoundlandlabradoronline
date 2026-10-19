# frozen_string_literal: true

Rails.application.routes.draw do # rubocop:disable Metrics/BlockLength
  get 'healthcheck', to: 'healthcheck#index'
  get 'live/:slug.jpg', to: 'newfoundland_labrador_online/live_images#show',
                        constraints: { slug: /[a-z-]+/ }, format: false
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html

  scope ':locale',
        locale: /#{I18n.available_locales.join('|')}/ do
    authenticated :user do # rubocop:todo Lint/EmptyBlock
    end

    # Geography lives under /g like CE's own geography tables; one sub-path per district type.
    scope 'g/districts' do
      resources :provincial, only: %i[index show], controller: 'newfoundland_labrador_online/districts',
                             as: :newfoundland_labrador_online_districts
    end
    get 'districts', to: redirect('/%{locale}/g/districts/provincial') # rubocop:disable Style/FormatStringToken
    get 'districts/:id', to: redirect('/%{locale}/g/districts/provincial/%{id}') # rubocop:disable Style/FormatStringToken

    resources :parties, only: :index, controller: 'newfoundland_labrador_online/parties',
                        as: :newfoundland_labrador_online_parties
    get 'parties/:jurisdiction/:id', to: 'newfoundland_labrador_online/parties#show',
                                     as: :newfoundland_labrador_online_party
    resources :elections, only: :index, controller: 'newfoundland_labrador_online/elections',
                          as: :newfoundland_labrador_online_elections
    get 'elections/:jurisdiction/:year', to: 'newfoundland_labrador_online/elections#show',
                                         as: :newfoundland_labrador_online_election,
                                         constraints: { year: /\d{4}/ }
    get 'locations/available', to: 'newfoundland_labrador_online/locations#available',
                               as: :newfoundland_labrador_online_available_locations
  end

  root to: redirect("/#{I18n.default_locale}")
  mount BetterTogether::Engine => '/'
end
