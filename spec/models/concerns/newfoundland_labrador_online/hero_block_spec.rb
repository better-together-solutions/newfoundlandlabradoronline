# frozen_string_literal: true

require 'rails_helper'

RSpec.describe NewfoundlandLabradorOnline::HeroBlock do
  let(:platform) { BetterTogether::Platform.find_by(host: true) || create(:better_together_platform) }
  let(:person) { create(:better_together_person) }
  let(:png) do
    Base64.strict_decode64(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=='
    )
  end
  let(:block) do
    BetterTogether::Content::Hero.new(platform:, privacy: 'private', identifier: 'shippage-test-hero', creator: person,
                                      background_image_data: Base64.strict_encode64(png),
                                      background_image_filename: 'ship.png', heading: 'EXPLORA III')
  end

  it 'extends the CE hero block' do
    expect(BetterTogether::Content::Hero.included_modules).to include(described_class)
  end

  it 'attaches a base64 background image', :aggregate_failures do
    block.save!

    expect(block.reload.background_image_file).to be_attached
    expect(block.background_image_file.content_type).to eq('image/png')
    expect(block.background_image_file.filename.to_s).to eq('ship.png')
  end

  it 'rejects data that is not an allowed image', :aggregate_failures do
    block.background_image_data = Base64.strict_encode64('not an image')

    expect(block).not_to be_valid
    expect(block.errors[:background_image_data]).to include('must be a JPEG, PNG or WebP image')
  end

  it 'rejects invalid base64' do
    block.background_image_data = '***'

    expect(block).not_to be_valid
  end

  it 'rejects oversized images', :aggregate_failures do
    padding = '0' * (NewfoundlandLabradorOnline::ImageInput::MAX_BYTES + 1)
    block.background_image_data = Base64.strict_encode64(png + padding)

    expect(block).not_to be_valid
    expect(block.errors[:background_image_data].join).to include('too large')
  end

  it 'does not keep the data after saving' do
    block.save!

    expect(block.background_image_data).to be_nil
  end

  it 'leaves an existing background alone when no data is sent', :aggregate_failures do
    block.save!
    block.update!(heading: 'EXPLORA III (updated)')

    expect(block.reload.background_image_file).to be_attached
  end
end
