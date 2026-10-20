# frozen_string_literal: true

Rails.application.routes.draw do # rubocop:disable Metrics/BlockLength
  get 'healthcheck', to: 'healthcheck#index'
  get 'live/:slug.jpg', to: 'newfoundland_labrador_online/live_images#show',
                        constraints: { slug: /[a-z-]+/ }, format: false
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html

  scope ':locale',
        locale: /#{I18n.available_locales.join('|')}/ do # rubocop:disable Metrics/BlockLength
    authenticated :user do # rubocop:todo Lint/EmptyBlock
    end

    # Election-related pages are grouped under /e. Each level (provincial) nests the province code (nl, ns, ...), which
    # is looked up in the geography states; the level's own path lists every province.
    # States are public like settlements, each page linking to the data scoped to it. /g/provinces is an alias used for
    # states that identify as provinces (State#province?); /g/states is the canonical default for any state.
    states = 'newfoundland_labrador_online/states'
    get 'g/states', to: "#{states}#index", as: :newfoundland_labrador_online_states
    get 'g/states/:id', to: "#{states}#show", as: :newfoundland_labrador_online_state
    get 'g/provinces', to: "#{states}#index", defaults: { provinces: true }, as: :newfoundland_labrador_online_provinces
    get 'g/provinces/:id', to: "#{states}#show", defaults: { provinces: true },
                           as: :newfoundland_labrador_online_province

    scope 'e' do # rubocop:disable Metrics/BlockLength
      province = { province: /[a-z]{2}/ }
      districts = 'newfoundland_labrador_online/districts'
      get 'districts', to: "#{districts}#index", as: :newfoundland_labrador_online_districts
      get 'districts/:jurisdiction', to: "#{districts}#index", as: :newfoundland_labrador_online_jurisdiction_districts,
                                     constraints: { jurisdiction: /provincial/ }
      get 'districts/provincial/:province', to: "#{districts}#index",
                                            as: :newfoundland_labrador_online_scoped_districts, constraints: province
      get 'districts/provincial/:province/:id', to: "#{districts}#show", as: :newfoundland_labrador_online_district,
                                                constraints: province

      get 'members/provincial/:province', to: 'newfoundland_labrador_online/legislatures#show',
                                          as: :newfoundland_labrador_online_legislature, constraints: province

      parties = 'newfoundland_labrador_online/parties'
      get 'parties', to: "#{parties}#index", as: :newfoundland_labrador_online_parties
      get 'parties/:jurisdiction', to: "#{parties}#index", as: :newfoundland_labrador_online_jurisdiction_parties,
                                   constraints: { jurisdiction: /provincial/ }
      get 'parties/:jurisdiction/:province', to: "#{parties}#index", as: :newfoundland_labrador_online_scoped_parties,
                                             constraints: { jurisdiction: /provincial/ }.merge(province)
      get 'parties/:jurisdiction/:province/:id', to: "#{parties}#show", as: :newfoundland_labrador_online_party,
                                                 constraints: { jurisdiction: /provincial/ }.merge(province)

      elections = 'newfoundland_labrador_online/elections'
      get 'elections', to: "#{elections}#index", as: :newfoundland_labrador_online_elections
      get 'elections/:jurisdiction', to: "#{elections}#index", as: :newfoundland_labrador_online_jurisdiction_elections,
                                     constraints: { jurisdiction: /provincial/ }
      get 'elections/:jurisdiction/:province', to: "#{elections}#index",
                                               as: :newfoundland_labrador_online_scoped_elections,
                                               constraints: { jurisdiction: /provincial/ }.merge(province)
      get 'elections/:jurisdiction/:province/:year', to: "#{elections}#show",
                                                     as: :newfoundland_labrador_online_election,
                                                     constraints: { jurisdiction: /provincial/, year: /\d{4}/,
                                                                    **province }
    end

    get 'locations/available', to: 'newfoundland_labrador_online/locations#available',
                               as: :newfoundland_labrador_online_available_locations
  end

  root to: redirect("/#{I18n.default_locale}")
  mount BetterTogether::Engine => '/'
end
