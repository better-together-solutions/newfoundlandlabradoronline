# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'newfoundland_labrador_online/image_blocks/_image_block' do
  let(:platform) { BetterTogether::Platform.find_by(host: true) || create(:better_together_platform) }
  let(:png) do
    Base64.strict_decode64(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=='
    )
  end
  let(:block) do
    BetterTogether::Content::Image.create!(
      platform:, privacy: 'private', identifier: 'attribution-test', creator: create(:better_together_person),
      media_data: Base64.strict_encode64(png), media_filename: 'ship.png', caption: 'EXPLORA III',
      attribution: 'Photo: Dag Chr Halvorsen, CC BY 4.0', attribution_url: 'https://commons.wikimedia.org/wiki/File:Ship.jpg'
    )
  end

  it 'credits the photographer with a link to the source', :aggregate_failures do
    render partial: 'newfoundland_labrador_online/image_blocks/image_block', locals: { image: block }

    expect(rendered).to include('Photo: Dag Chr Halvorsen, CC BY 4.0')
    expect(rendered).to include('href="https://commons.wikimedia.org/wiki/File:Ship.jpg"')
    expect(rendered).to include('rel="noopener noreferrer"')
    expect(rendered).to include('fa-external-link-alt')
  end

  it 'shows attribution without a link when there is no URL', :aggregate_failures do
    block.update!(attribution_url: nil)
    render partial: 'newfoundland_labrador_online/image_blocks/image_block', locals: { image: block }

    expect(rendered).to include('Photo: Dag Chr Halvorsen, CC BY 4.0')
    expect(rendered).not_to include('<a ')
  end

  it 'adds no attribution line when there is none', :aggregate_failures do
    block.update!(attribution: nil, attribution_url: nil)
    render partial: 'newfoundland_labrador_online/image_blocks/image_block', locals: { image: block }

    expect(rendered).not_to include('post-image__attribution')
    expect(rendered).to include('figure-caption')
  end
end
