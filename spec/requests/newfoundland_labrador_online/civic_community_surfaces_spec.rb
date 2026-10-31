# frozen_string_literal: true

require 'rails_helper'

# Where a public civic community (party, legislature, ...) may appear in CE's discovery surfaces.
# Civic communities are public on purpose and served at their own URL, but are not listed in generic
# discovery: communities index, search, sitemap and every list built from policy_scope(Community).
RSpec.describe 'Civic community visibility across CE surfaces' do
  include RequestSpecHelper

  let(:host_platform) { configure_host_platform.tap { |platform| platform.update!(privacy: 'public') } }
  let!(:party) do
    host_platform
    NewfoundlandLabradorOnline::PartyCommunity.create!(identifier: 'surface-matrix-party', name: 'Surface Matrix Party',
                                                       privacy: 'public', host: false, protected: false)
  end
  let!(:ordinary) { create(:better_together_community, name: 'Surface Matrix Club', privacy: 'public') }

  describe 'communities index' do
    it 'lists the ordinary community and not the party', :aggregate_failures do
      get better_together.communities_path(locale: I18n.locale)

      expect(response.body).to include(ordinary.name)
      expect(response.body).not_to include(party.name)
    end
  end

  describe 'global search' do
    it 'does not return the party', :aggregate_failures do
      get better_together.search_path(locale: I18n.locale, q: 'Surface Matrix')

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include(party.name)
    end
  end

  describe 'sitemap' do
    let(:sitemap) do
      Class.new do
        attr_reader :paths

        def initialize = @paths = []
        def add(path, **) = @paths << path
      end.new
    end

    it 'indexes the ordinary community and not the party', :aggregate_failures do
      BetterTogether::SitemapHelper.add_communities(sitemap, I18n.default_locale, platform: host_platform)

      expect(sitemap.paths.join(' ')).to include(ordinary.slug)
      expect(sitemap.paths.join(' ')).not_to include(party.slug)
    end
  end

  # MCP list_communities and public_communities, the resource block community picker, the map visible scope,
  # the posts community filter and the settlement "located communities" list all call policy_scope(Community).
  describe 'policy_scope(Community)' do
    let(:manager) { BetterTogether::User.find_by(email: 'manager@example.test').person }

    it 'omits the party for an anonymous visitor and for a platform manager', :aggregate_failures do
      [nil, manager.user].each do |user|
        scope = BetterTogether::CommunityPolicy::Scope.new(user, BetterTogether::Community).resolve

        expect(scope).to include(ordinary)
        expect(scope).not_to include(party)
      end
    end
  end

  describe 'person profile' do
    let(:member) { create(:better_together_person) }

    before do
      role = BetterTogether::Role.find_by(identifier: 'community_member') ||
             create(:better_together_role, :community_role)
      create(:better_together_person_community_membership, member:, joinable: party, role:)
    end

    it 'lists the seat on the member\'s own profile' do
      create(:user, :confirmed, person: member, email: 'seat-holder@example.test', password: 'SecureTest123!@#')
      login('seat-holder@example.test', 'SecureTest123!@#')
      get better_together.person_path(member, locale: I18n.locale)

      expect(response.body).to include(party.name)
    end

    it 'does not show the seat to an anonymous visitor' do
      get better_together.person_path(member, locale: I18n.locale)

      expect(response.body).not_to include(party.name)
    end
  end
end
