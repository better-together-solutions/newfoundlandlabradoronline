# frozen_string_literal: true

require 'rails_helper'

RSpec.describe NewfoundlandLabradorOnline::PostCoverImage do
  let(:platform) { BetterTogether::Platform.find_by(host: true) || create(:better_together_platform) }
  let(:person) { create(:better_together_person) }
  let(:png) do
    Base64.strict_decode64(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=='
    )
  end
  let(:post) do
    build(:better_together_post, platform:, privacy: 'private', author: person)
  end

  def encode(bytes)
    Base64.strict_encode64(bytes)
  end

  it 'attaches a valid image as the cover on create', :aggregate_failures do
    post.assign_attributes(cover_image_data: encode(png), cover_image_filename: 'frame.png')
    post.save!

    expect(post.reload.cover_image).to be_attached
    expect(post.cover_image.content_type).to eq('image/png')
    expect(post.cover_image.filename.to_s).to eq('frame.png')
  end

  it 'names the file from its type when no filename is given' do
    post.cover_image_data = encode(png)
    post.save!

    expect(post.reload.cover_image.filename.to_s).to eq('cover.png')
  end

  it 'reduces the filename to a safe basename' do
    post.assign_attributes(cover_image_data: encode(png), cover_image_filename: '../../etc/pass wd.png')
    post.save!

    expect(post.reload.cover_image.filename.to_s).to eq('pass_wd.png')
  end

  it 'replaces the cover on update' do
    post.cover_image_data = encode(png)
    post.save!
    post.update!(cover_image_data: encode(png), cover_image_filename: 'second.png')

    expect(post.reload.cover_image.filename.to_s).to eq('second.png')
  end

  it 'leaves the cover alone when no data is given' do
    post.cover_image_data = encode(png)
    post.save!
    post.update!(title: 'Renamed')

    expect(post.reload.cover_image).to be_attached
  end

  it 'does not keep the data after saving' do
    post.cover_image_data = encode(png)
    post.save!

    expect(post.cover_image_data).to be_nil
  end

  {
    'invalid base64' => ['not base64 !!', 'is not valid base64'],
    'non-image bytes' => [Base64.strict_encode64('plain text'), 'must be a JPEG, PNG or WebP image'],
    'SVG' => [Base64.strict_encode64('<svg xmlns="http://www.w3.org/2000/svg"></svg>'),
              'must be a JPEG, PNG or WebP image']
  }.each do |label, (data, message)|
    it "rejects #{label}", :aggregate_failures do
      post.cover_image_data = data

      expect(post).not_to be_valid
      expect(post.errors[:cover_image_data]).to include(message)
    end
  end

  it 'rejects an image over the size limit', :aggregate_failures do
    stub_const('BetterTogether::ImageInput::MAX_BYTES', 10)
    post.cover_image_data = encode(png)

    expect(post).not_to be_valid
    expect(post.errors[:cover_image_data].join).to include('too large')
  end
end
