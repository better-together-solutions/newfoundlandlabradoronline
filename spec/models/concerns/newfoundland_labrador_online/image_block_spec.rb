# frozen_string_literal: true

require 'rails_helper'

RSpec.describe NewfoundlandLabradorOnline::ImageBlock do
  let(:platform) { BetterTogether::Platform.find_by(host: true) || create(:better_together_platform) }
  let(:person) { create(:better_together_person) }
  let(:png) do
    Base64.strict_decode64(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=='
    )
  end
  let(:block) do
    BetterTogether::Content::Image.new(platform:, privacy: 'private', identifier: 'sky-test', creator: person,
                                       media_data: Base64.strict_encode64(png), media_filename: 'civil-dawn.png',
                                       caption: 'Civil dawn, 06:58', alt_text: 'The sky before sunrise')
  end

  it 'extends the CE image block' do
    expect(BetterTogether::Content::Image.included_modules).to include(described_class)
  end

  it 'attaches a base64 image and keeps the caption', :aggregate_failures do
    block.save!

    expect(block.reload.media).to be_attached
    expect(block.media.content_type).to eq('image/png')
    expect(block.media.filename.to_s).to eq('civil-dawn.png')
    expect(block.caption).to eq('Civil dawn, 06:58')
  end

  it 'requires a caption for images created from data', :aggregate_failures do
    block.caption = nil

    expect(block).not_to be_valid
    expect(block.errors[:caption]).to be_present
  end

  it 'rejects data that is not an allowed image', :aggregate_failures do
    block.media_data = Base64.strict_encode64('not an image')

    expect(block).not_to be_valid
    expect(block.errors[:media_data]).to include('must be a JPEG, PNG or WebP image')
  end

  it 'rejects invalid base64 and oversized images', :aggregate_failures do
    block.media_data = '***'
    expect(block).not_to be_valid

    block.media_data = Base64.strict_encode64(png + ('0' * (NewfoundlandLabradorOnline::ImageInput::MAX_BYTES + 1)))
    expect(block).not_to be_valid
    expect(block.errors[:media_data].join).to include('too large')
  end

  it 'does not keep the data after saving' do
    block.save!

    expect(block.media_data).to be_nil
  end

  describe 'attachable behaviour' do
    before { block.save! }

    it 'round trips through a signed global id' do
      expect(ActionText::Attachable.from_attachable_sgid(block.attachable_sgid)).to eq(block)
    end

    it 'uses its caption as the plain text representation' do
      expect(block.attachable_plain_text_representation).to eq('Civil dawn, 06:58')
    end

    it 'survives a Trix round trip as an attachment', :aggregate_failures do
      html = ActionText::Attachment.from_attachable(block).to_html
      content = ActionText::Content.new(html)

      expect(content.to_trix_html).to include('data-trix-attachment')
      expect(content.attachables).to eq([block])
    end
  end
end
