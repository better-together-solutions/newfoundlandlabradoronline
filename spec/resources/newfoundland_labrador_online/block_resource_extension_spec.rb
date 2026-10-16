# frozen_string_literal: true

require 'rails_helper'

RSpec.describe NewfoundlandLabradorOnline::BlockResourceExtension do
  let(:resource) { BetterTogether::Api::V1::BlockResource }

  it 'accepts the image input on create and update', :aggregate_failures do
    expect(resource.creatable_fields({})).to include(:media_data, :media_filename)
    expect(resource.updatable_fields({})).to include(:media_data, :media_filename)
  end

  it 'never returns the write-only image input' do
    fields = resource.new(BetterTogether::Content::Image.new, {}).fetchable_fields

    expect(fields).not_to include(:media_data, :media_filename)
  end

  it 'sets the image input on an image block' do
    block = BetterTogether::Content::Image.new
    resource.new(block, {}).media_data = 'abc'

    expect(block.media_data).to eq('abc')
  end

  it 'refuses the image input on other block types' do
    instance = resource.new(BetterTogether::Content::Markdown.new, {})

    expect { instance.media_data = 'abc' }.to raise_error(JSONAPI::Exceptions::InvalidFieldValue)
  end
end
