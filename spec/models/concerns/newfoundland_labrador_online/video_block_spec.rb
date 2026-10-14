# frozen_string_literal: true

require 'rails_helper'

RSpec.describe NewfoundlandLabradorOnline::VideoBlock do
  let(:platform) { BetterTogether::Platform.find_by(host: true) || create(:better_together_platform) }
  let(:block) do
    BetterTogether::Content::VideoBlock.new(platform:, privacy: 'private', identifier: 'vb-1',
                                            creator: create(:better_together_person),
                                            video_url: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ')
  end

  it 'extends the CE video block' do
    expect(BetterTogether::Content::VideoBlock.included_modules).to include(described_class)
  end

  describe 'aspect ratio' do
    it 'accepts the vertical 9x16 ratio and the CE ratios', :aggregate_failures do
      %w[16x9 4x3 1x1 9x16].each do |ratio|
        block.aspect_ratio = ratio
        expect(block).to be_valid, "#{ratio} should be valid"
      end
    end

    it 'rejects other ratios', :aggregate_failures do
      block.aspect_ratio = '21x9'

      expect(block).not_to be_valid
      expect(block.errors[:aspect_ratio]).to be_present
    end

    it 'keeps a single aspect ratio inclusion validator' do
      validators = BetterTogether::Content::VideoBlock.validators_on(:aspect_ratio)

      expect(validators.grep(ActiveModel::Validations::InclusionValidator).size).to eq(1)
    end
  end

  describe '#attachment_embed_url' do
    it 'uses the privacy-enhanced YouTube host' do
      expect(block.attachment_embed_url).to eq('https://www.youtube-nocookie.com/embed/dQw4w9WgXcQ')
    end

    it 'leaves other providers unchanged' do
      block.video_url = 'https://vimeo.com/123456789'

      expect(block.attachment_embed_url).to eq('https://player.vimeo.com/video/123456789')
    end
  end

  describe 'attachable behaviour' do
    before { block.save! }

    it 'round trips through a signed global id' do
      expect(ActionText::Attachable.from_attachable_sgid(block.attachable_sgid)).to eq(block)
    end

    it 'survives a Trix round trip as an attachment', :aggregate_failures do
      html = ActionText::Attachment.from_attachable(block).to_html
      content = ActionText::Content.new(html)

      expect(content.to_trix_html).to include('data-trix-attachment', block.video_url)
      expect(content.attachables).to eq([block])
    end
  end

  it 'reports portrait for 9x16' do
    block.aspect_ratio = '9x16'

    expect(block).to be_portrait
  end
end
