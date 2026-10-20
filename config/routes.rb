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
    scope 'e' do # rubocop:disable Metrics/BlockLength
      province = { province: /[a-z]{2}/ }
      districts = 'newfoundland_labrador_online/districts'
      get 'districts/provincial', to: "#{districts}#index", as: :newfoundland_labrador_online_districts
      get 'districts/provincial/:province', to: "#{districts}#index",
                                            as: :newfoundland_labrador_online_scoped_districts, constraints: province
      get 'districts/provincial/:province/:id', to: "#{districts}#show", as: :newfoundland_labrador_online_district,
                                                constraints: province

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

    # Earlier public paths redirect to /e; they only ever served Newfoundland and Labrador.
    # rubocop:disable Style/FormatStringToken
    get 'districts', to: redirect('/%{locale}/e/districts/provincial')
    get 'districts/:id', to: redirect('/%{locale}/e/districts/provincial/nl/%{id}')
    get 'g/districts/provincial', to: redirect('/%{locale}/e/districts/provincial')
    get 'g/districts/provincial/:id', to: redirect('/%{locale}/e/districts/provincial/nl/%{id}')
    get 'parties', to: redirect('/%{locale}/e/parties')
    get 'parties/:jurisdiction', to: redirect('/%{locale}/e/parties/%{jurisdiction}')
    get 'parties/:jurisdiction/:id', to: redirect('/%{locale}/e/parties/%{jurisdiction}/nl/%{id}')
    get 'elections', to: redirect('/%{locale}/e/elections')
    get 'elections/:jurisdiction', to: redirect('/%{locale}/e/elections/%{jurisdiction}')
    get 'elections/:jurisdiction/:year', to: redirect('/%{locale}/e/elections/%{jurisdiction}/nl/%{year}')
    # rubocop:enable Style/FormatStringToken
    get 'locations/available', to: 'newfoundland_labrador_online/locations#available',
                               as: :newfoundland_labrador_online_available_locations
  end

  root to: redirect("/#{I18n.default_locale}")
  mount BetterTogether::Engine => '/'
end
