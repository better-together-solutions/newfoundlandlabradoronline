# frozen_string_literal: true

require 'rails_helper'

# Civic roles appear in CE's roles management under one tab per community subtype, labelled in the host's words.
RSpec.describe 'Roles management', type: :request do
  include RequestSpecHelper

  let(:locale) { I18n.default_locale }

  before do
    configure_host_platform
    NewfoundlandLabradorOnline::Civic::RoleSeeder.call
    login('manager@example.test', 'SecureTest123!@#')
  end

  it 'lists civic roles under a labelled tab per community subtype', :aggregate_failures do
    get "/#{locale}/host/roles"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Party roles', 'Legislature roles',
                                     'roles-newfoundlandlabradoronline-partycommunity')
    expect(response.body).to include('Party leader', 'Speaker')
  end

  it 'shows a civic role with its subtype label' do
    role = BetterTogether::Role.find_by!(identifier: 'party_leader')
    get "/#{locale}/host/roles/#{role.slug}"

    expect(response.body).to include('Party roles')
  end
end
