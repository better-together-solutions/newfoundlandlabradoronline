# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'better_together/communities show hook partials' do
  helper BetterTogether::ApplicationHelper, BetterTogether::ImageHelper, BetterTogether::CommunityMarkHelper

  include RequestSpecHelper

  before { configure_host_platform.update!(privacy: 'public') }

  let(:community) { create(:better_together_community, name: 'Rotary Arts Centre') }
  let(:picture) { Rails.root.join('spec/fixtures/covers/nl-ped-st-john-s-centre.jpg') }

  def attach(attachment)
    community.public_send(attachment).attach(io: File.open(picture), filename: 'mark.jpg', content_type: 'image/jpeg')
  end

  describe '_header_media' do
    def render_header
      render partial: 'better_together/communities/header_media', locals: { community: }
    end

    it 'keeps the CE ids and shows the profile image when there is no logo', :aggregate_failures do
      render_header

      expect(rendered).to include("id=\"#{dom_id(community, :cover)}\"", "id=\"#{dom_id(community, :profile_image)}\"")
      expect(rendered).not_to include('community-logo-tile', 'community-header-mark')
    end

    it 'puts the logo in a tile in the profile image place' do
      attach(:cover_image)
      attach(:logo)
      render_header

      expect(rendered).to include("id=\"#{dom_id(community, :logo_tile)}\"")
    end

    it 'shows the mark large when there is no cover', :aggregate_failures do
      attach(:profile_image)
      render_header

      expect(rendered).to include("id=\"#{dom_id(community, :header_mark)}\"")
      expect(rendered).not_to include("id=\"#{dom_id(community, :profile_image)}\"")
    end
  end

  describe '_location_line' do
    def render_line
      render partial: 'better_together/communities/location_line', locals: { community: }
    end

    it 'links the settlement the community is located in', :aggregate_failures do
      settlement = create(:geography_settlement, identifier: 'corner-brook', privacy: 'private')
      community.create_location!(location: settlement)
      render_line

      expect(rendered).to include(settlement.name)
      expect(rendered).to include('/g/settlements/corner-brook"')
    end

    it 'renders nothing when the community has no location' do
      render_line

      expect(rendered.strip).to be_empty
    end
  end

  describe '_about_extra' do
    it 'renders nothing for a community without a live image' do
      render partial: 'better_together/communities/about_extra', locals: { community: }

      expect(rendered.strip).to be_empty
    end

    it 'renders the live image card for a listed community' do
      allow(NewfoundlandLabradorOnline::LiveImage).to receive(:slug_for).with(community).and_return('corner-brook')
      render partial: 'better_together/communities/about_extra', locals: { community: }

      expect(rendered).to include('data-controller="live-image"')
    end
  end
end
