# frozen_string_literal: true

require 'rails_helper'

RSpec.describe NewfoundlandLabradorOnline::PostResourceExtension do
  let(:resource) { BetterTogether::Api::V1::PostResource }

  it 'adds the publisher fields to creatable fields' do
    expect(resource.creatable_fields({})).to include(
      :community_id, :published_at, :video_url, :video_orientation, :legacy_video_embed,
      :category_identifiers, :contributor_specs
    )
  end

  it 'keeps slug read-only' do
    expect(resource.creatable_fields({})).not_to include(:slug)
  end

  it 'does not let contributor_specs be changed after creation' do
    expect(resource.updatable_fields({})).not_to include(:contributor_specs)
  end

  it 'exposes the video attributes' do
    expect(resource._attributes.keys).to include(:video_url, :video_orientation, :legacy_video_embed)
  end
end
