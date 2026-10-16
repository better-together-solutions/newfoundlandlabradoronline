# frozen_string_literal: true

require 'rails_helper'

RSpec.describe NewfoundlandLabradorOnline::BlockResourceExtension do
  let(:resource) { BetterTogether::Api::V1::BlockResource }

  it 'accepts the image input on create and update', :aggregate_failures do
    expect(resource.creatable_fields({})).to include(:media_data, :media_filename)
    expect(resource.updatable_fields({})).to include(:media_data, :media_filename)
  end

  it 'accepts the hero background input on create and update', :aggregate_failures do
    expect(resource.creatable_fields({})).to include(:background_image_data, :background_image_filename)
    expect(resource.updatable_fields({})).to include(:background_image_data, :background_image_filename)
  end

  it 'never returns the write-only image input' do
    fields = resource.new(BetterTogether::Content::Image.new, {}).fetchable_fields

    expect(fields).not_to include(:media_data, :media_filename, :background_image_data, :background_image_filename)
  end

  it 'sets the background image input on a hero block' do
    block = BetterTogether::Content::Hero.new
    resource.new(block, {}).background_image_data = 'abc'

    expect(block.background_image_data).to eq('abc')
  end

  it 'refuses the background image input on other block types' do
    instance = resource.new(BetterTogether::Content::Image.new, {})

    expect { instance.background_image_data = 'abc' }.to raise_error(JSONAPI::Exceptions::InvalidFieldValue)
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
