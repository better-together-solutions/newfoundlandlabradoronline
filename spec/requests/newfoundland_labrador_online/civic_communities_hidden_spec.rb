# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Civic communities and the CE communities index' do
  include RequestSpecHelper

  let(:party) do
    NewfoundlandLabradorOnline::PartyCommunity.create!(identifier: 'party-hidden-test', name: 'Hidden Test Party',
                                                       privacy: 'public', host: false, protected: false)
  end

  before do
    configure_host_platform.update!(privacy: 'public')
    party
    create(:better_together_community, name: 'Ordinary Test Community', privacy: 'public')
  end

  it 'lists ordinary public communities but not civic ones', :aggregate_failures do
    get better_together.communities_path(locale: I18n.locale)

    expect(response.body).to include('Ordinary Test Community')
    expect(response.body).not_to include('Hidden Test Party')
  end

  it 'still serves a civic community at its own URL' do
    get better_together.community_path(party, locale: I18n.locale)

    expect(response.status).to eq(200), "got #{response.status} #{response.location}"
  end
end
