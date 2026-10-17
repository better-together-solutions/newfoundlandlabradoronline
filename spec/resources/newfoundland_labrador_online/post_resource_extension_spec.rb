# frozen_string_literal: true

require 'rails_helper'

RSpec.describe NewfoundlandLabradorOnline::PostResourceExtension do
  let(:resource) { BetterTogether::Api::V1::PostResource }

  it 'pins updated_at to a backfilled created_at', :aggregate_failures do
    post = BetterTogether::Post.new
    resource.new(post, {}).created_at = Time.zone.parse('2026-09-30 06:30')

    expect(post.updated_at).to eq(post.created_at)
    expect(post.pin_timestamps_to_creation).to be(true)
  end

  it 'lets a backfill set created_at on create but never on update', :aggregate_failures do
    expect(resource.creatable_fields({})).to include(:created_at)
    expect(resource.updatable_fields({})).not_to include(:created_at)
  end

  it 'accepts updated_at on create and update and remembers it for the model', :aggregate_failures do
    expect(resource.creatable_fields({})).to include(:updated_at)
    expect(resource.updatable_fields({})).to include(:updated_at)
    post = BetterTogether::Post.new
    resource.new(post, {}).updated_at = Time.zone.parse('2026-09-30 06:30')

    expect(post.pinned_updated_at).to eq(Time.zone.parse('2026-09-30 06:30'))
  end

  it 'adds the publisher fields to creatable fields' do
    expect(resource.creatable_fields({})).to include(
      :community_id, :published_at, :video_block_id, :category_identifiers, :contributor_specs
    )
  end

  it 'accepts the cover image fields on create and update but never returns them', :aggregate_failures do
    expect(resource.creatable_fields({})).to include(:cover_image_data, :cover_image_filename)
    expect(resource.updatable_fields({})).to include(:cover_image_data, :cover_image_filename)
    expect(resource.new(BetterTogether::Post.new, {}).fetchable_fields).not_to include(:cover_image_data)
  end

  it 'accepts the attachment block ids on create and update and never returns them', :aggregate_failures do
    expect(resource.creatable_fields({})).to include(:attachment_block_ids)
    expect(resource.updatable_fields({})).to include(:attachment_block_ids)
    expect(resource.new(BetterTogether::Post.new, {}).fetchable_fields).not_to include(:attachment_block_ids)
  end

  it 'keeps slug read-only' do
    expect(resource.creatable_fields({})).not_to include(:slug)
  end

  it 'accepts contributors and the video input on create only' do
    expect(resource.updatable_fields({})).not_to include(:contributor_specs, :video_block_id)
  end

  it 'never returns the write-only video block id' do
    instance = resource.new(BetterTogether::Post.new, {})

    expect(instance.fetchable_fields).not_to include(:video_block_id)
  end
end
