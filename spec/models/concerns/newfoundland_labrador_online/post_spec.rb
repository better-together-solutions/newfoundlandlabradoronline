# frozen_string_literal: true

require 'rails_helper'

RSpec.describe NewfoundlandLabradorOnline::Post do
  let(:platform) { BetterTogether::Platform.find_by(host: true) || create(:better_together_platform) }
  let(:person) { create(:better_together_person) }
  let(:post) do
    build(:better_together_post, platform:, privacy: 'private', author: person).tap do |record|
      record.video_url = 'https://www.youtube.com/watch?v=dQw4w9WgXcQ'
      record.video_orientation = 'landscape'
    end
  end

  it 'extends BetterTogether::Post' do
    expect(BetterTogether::Post.included_modules).to include(described_class)
  end

  describe 'video fields' do
    it 'accepts a YouTube url and uses the privacy-enhanced embed host', :aggregate_failures do
      expect(post).to be_valid
      expect(post.video_embed_url).to eq('https://www.youtube-nocookie.com/embed/dQw4w9WgXcQ')
    end

    it 'accepts YouTube Shorts urls', :aggregate_failures do
      post.video_url = 'https://www.youtube.com/shorts/dQw4w9WgXcQ'
      post.video_orientation = 'portrait'

      expect(post).to be_valid
      expect(post.video_aspect_ratio).to eq('9x16')
    end

    it 'rejects unsupported video hosts', :aggregate_failures do
      post.video_url = 'https://example.com/video.mp4'

      expect(post).not_to be_valid
      expect(post.errors[:video_url]).to be_present
    end

    it 'rejects unknown orientations' do
      post.video_orientation = 'square'

      expect(post).not_to be_valid
    end

    it 'defaults to a 16x9 frame' do
      post.video_orientation = nil

      expect(post.video_aspect_ratio).to eq('16x9')
    end
  end

  describe '#category_identifiers=' do
    before { NewfoundlandLabradorOnline::VideoCategories.seed!(platform:) }

    it 'assigns categories by identifier', :aggregate_failures do
      post.category_identifiers = %w[timelapse daily-timelapse]
      post.save!

      expect(post.reload.category_identifiers).to match_array(%w[timelapse daily-timelapse])
    end

    it 'is invalid when an identifier is unknown', :aggregate_failures do
      post.category_identifiers = %w[timelapse nope]

      expect(post).not_to be_valid
      expect(post.errors[:base].join).to include('nope')
    end
  end

  describe '#contributor_specs=' do # rubocop:disable RSpec/MultipleMemoizedHelpers
    let(:robot) do
      BetterTogether::Robot.create!(name: 'CBO Publisher', identifier: 'cbo-publisher', platform:,
                                    robot_type: 'automation', provider: 'ollama')
    end
    let(:editor) { create(:better_together_person) }

    let(:plain_post) do
      BetterTogether::Post.new(title: 'CBO video', content: 'Video', identifier: 'cbo-video-1', platform:,
                               privacy: 'private', creator: person)
    end

    it 'builds robot author and person editor contributions without adding the creator' do # rubocop:disable RSpec/ExampleLength
      post = plain_post
      post.contributor_specs = [
        { author_type: 'BetterTogether::Robot', author_id: robot.id, role: 'author', position: 0 },
        { author_type: 'BetterTogether::Person', author_id: editor.id, role: 'editor', position: 1 }
      ]
      post.save!

      roles = post.reload.contributions.pluck(:author_type, :role)
      expect(roles).to contain_exactly(['BetterTogether::Robot', 'author'], ['BetterTogether::Person', 'editor'])
    end

    it 'rejects unsupported contributor types' do
      plain_post.contributor_specs = [{ author_type: 'BetterTogether::Community', author_id: 'x' }]

      expect(plain_post).not_to be_valid
    end
  end
end
