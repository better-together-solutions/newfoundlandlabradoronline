# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Municipal elections on the public elections pages' do
  include RequestSpecHelper

  before { configure_host_platform }

  it 'are not listed with provincial elections', :aggregate_failures do
    council = NewfoundlandLabradorOnline::LegislatureCommunity.create!(identifier: 'council-x', name: 'X Council')
    NewfoundlandLabradorOnline::Election.create!(jurisdiction: 'municipal', community: council, held_on: '2025-10-02')

    get "/#{I18n.default_locale}/e/elections"

    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include('2025')
  end
end
