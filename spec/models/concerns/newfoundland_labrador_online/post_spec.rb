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
    it 'accepts a YouTube url' do
      expect(post).to be_valid
    end

    it 'accepts YouTube Shorts urls', :aggregate_failures do
      post.video_url = 'https://www.youtube.com/shorts/dQw4w9WgXcQ'
      post.video_orientation = 'portrait'

      expect(post).to be_valid
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
  end

  describe 'video attachment' do
    def attached_blocks(record)
      BetterTogether::Post.find(record.id).content.body.attachables
                          .grep(BetterTogether::Content::VideoBlock)
    end

    it 'attaches the post video block ahead of the description', :aggregate_failures do
      post.content = 'Daily timelapse description'
      post.save!

      expect(attached_blocks(post).map(&:video_url)).to eq(['https://www.youtube.com/watch?v=dQw4w9WgXcQ'])
      expect(post.reload.content.body.to_html).to match(/\A<action-text-attachment.*Daily timelapse description/m)
    end

    it 'creates a landscape block that mirrors the post privacy and creator', :aggregate_failures do
      post.save!
      block = attached_blocks(post).first

      expect(block).to have_attributes(aspect_ratio: '16x9', privacy: post.privacy, creator_id: post.creator_id,
                                       identifier: "video-#{post.identifier}")
    end

    it 'uses a 9x16 block for portrait videos' do
      post.assign_attributes(video_url: 'https://www.youtube.com/shorts/dQw4w9WgXcQ', video_orientation: 'portrait')
      post.save!

      expect(attached_blocks(post).first.aspect_ratio).to eq('9x16')
    end

    it 'does not duplicate the attachment or block when saved again', :aggregate_failures do
      post.save!
      post.update!(title: 'Renamed')

      expect(attached_blocks(post).size).to eq(1)
      expect(BetterTogether::Content::VideoBlock.where(identifier: "video-#{post.identifier}").count).to eq(1)
    end

    it 'updates the same block when the video changes', :aggregate_failures do
      post.save!
      block_id = attached_blocks(post).first.id
      post.update!(video_url: 'https://www.youtube.com/watch?v=abcdefghijk')

      expect(attached_blocks(post).map(&:id)).to eq([block_id])
      expect(attached_blocks(post).first.video_url).to include('abcdefghijk')
    end

    it 'changes only the orientation when given no new url', :aggregate_failures do
      post.save!
      BetterTogether::Post.find(post.id).update!(video_orientation: 'portrait')

      expect(attached_blocks(post).first).to be_portrait
    end

    it 'reads video_url and video_orientation back from the attachment', :aggregate_failures do
      post.assign_attributes(video_url: 'https://www.youtube.com/shorts/dQw4w9WgXcQ', video_orientation: 'portrait')
      post.save!
      reloaded = BetterTogether::Post.find(post.id)

      expect(reloaded).to have_attributes(video_url: 'https://www.youtube.com/shorts/dQw4w9WgXcQ',
                                          video_orientation: 'portrait')
    end

    it 'does not store the video input in display_settings' do
      post.save!

      expect(post.reload.display_settings.keys).not_to include('video_url', 'video_orientation')
    end

    it 'does not re-add a video an editor removed from the body', :aggregate_failures do
      post.save!
      edited = BetterTogether::Post.find(post.id)
      edited.update!(content: '<div>Text only</div>')

      expect(attached_blocks(edited)).to be_empty
      expect(edited.video_url).to be_nil
    end

    def render_body(record)
      BetterTogether::PostsController.render(inline: '<%= render_action_text_content(c) %>',
                                             locals: { c: record.reload.content.body })
    end

    it 'renders the iframe once the block is public', :aggregate_failures do
      post.save!
      block = attached_blocks(post).first
      block.seed_privacy_ceiling_exempt = true
      block.update!(privacy: 'public')

      expect(render_body(post)).to include('youtube-nocookie.com/embed/dQw4w9WgXcQ', 'ratio-16x9')
    end

    it 'holds the video while the block is not public' do
      post.save!

      expect(render_body(post)).to include('held-review')
    end

    it 'destroys the owned block with the post' do
      post.save!
      identifier = "video-#{post.identifier}"
      post.destroy!

      expect(BetterTogether::Content::VideoBlock.where(identifier:)).to be_empty
    end

    it 'adds no attachment without a video url' do
      post.video_url = nil
      post.save!

      expect(attached_blocks(post)).to be_empty
    end
  end

  describe '#category_identifiers=' do
    before { NewfoundlandLabradorOnline::VideoCategoryBuilder.seed_data(platform:) }

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
