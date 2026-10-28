# frozen_string_literal: true

require 'rails_helper'

RSpec.describe NewfoundlandLabradorOnline::PostResourceExtension do
  let(:resource) { BetterTogether::Api::V1::PostResource }

  it 'adds the publisher fields to creatable fields' do
    expect(resource.creatable_fields({})).to include(
      :community_id, :published_at, :contributor_specs
    )
  end

  it 'keeps slug read-only' do
    expect(resource.creatable_fields({})).not_to include(:slug)
  end

  it 'accepts contributors on create only' do
    expect(resource.updatable_fields({})).not_to include(:contributor_specs)
  end
end
