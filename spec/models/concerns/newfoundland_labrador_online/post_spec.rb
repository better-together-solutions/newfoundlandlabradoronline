# frozen_string_literal: true

require 'rails_helper'

RSpec.describe NewfoundlandLabradorOnline::Post do
  let(:platform) { BetterTogether::Platform.find_by(host: true) || create(:better_together_platform) }
  let(:person) { create(:better_together_person) }
  let(:post) do
    build(:better_together_post, platform:, privacy: 'private', author: person)
  end
  let(:video_block) do
    BetterTogether::Content::VideoBlock.create!(
      platform:, creator: person, privacy: 'private', identifier: 'yt-dQw4w9WgXcQ',
      video_url: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ'
    )
  end

  it 'extends BetterTogether::Post' do
    expect(BetterTogether::Post.included_modules).to include(described_class)
  end

  describe 'backfilled timestamps' do
    let(:original) { Time.zone.parse('2026-09-30 06:30') }

    it 'keeps updated_at equal to created_at after saving when pinned', :aggregate_failures do
      post.created_at = post.updated_at = original
      post.pin_timestamps_to_creation = true
      post.save!

      expect(post.reload.created_at).to be_within(1.second).of(original)
      expect(post.updated_at).to be_within(1.second).of(original)
    end

    it 'sets updated_at back on a later update when one is pinned', :aggregate_failures do
      post.save!
      post.update!(title: 'Changed', pinned_updated_at: original)

      expect(post.reload.updated_at).to be_within(1.second).of(original)
      expect(post.pinned_updated_at).to be_nil
    end

    it 'leaves updated_at alone when not pinned' do
      post.save!

      expect(post.reload.updated_at).to be_within(1.minute).of(Time.zone.now)
    end
  end

  describe 'posts without a video block' do
    it 'attaches nothing and does not touch video blocks', :aggregate_failures do
      allow(BetterTogether::Content::VideoBlock).to receive(:find_by).and_call_original
      post.content = '<p>Hello</p>'

      expect { post.save! }.not_to change(BetterTogether::Content::VideoBlock, :count)
      expect(BetterTogether::Content::VideoBlock).not_to have_received(:find_by)
      expect(post.reload.content.body.attachables).to be_empty
    end
  end

  describe 'video block attachment' do
    def attached_blocks(record)
      BetterTogether::Post.find(record.id).content.body.attachables.grep(BetterTogether::Content::VideoBlock)
    end

    def render_body(record)
      BetterTogether::PostsController.render(inline: '<%= render_action_text_content(c) %>',
                                             locals: { c: record.reload.content.body })
    end

    it 'attaches the block ahead of the description', :aggregate_failures do
      post.assign_attributes(content: 'Daily timelapse description', video_block_id: video_block.id)
      post.save!

      expect(attached_blocks(post)).to eq([video_block])
      expect(post.reload.content.body.to_html).to match(/\A<action-text-attachment.*Daily timelapse description/m)
    end

    it 'does not create, change or delete the block', :aggregate_failures do
      post.video_block_id = video_block.id

      expect { post.save! }.not_to change(BetterTogether::Content::VideoBlock, :count)
      expect { post.destroy! }.not_to change(BetterTogether::Content::VideoBlock, :count)
    end

    it 'rejects an unknown block id', :aggregate_failures do
      post.video_block_id = SecureRandom.uuid

      expect(post).not_to be_valid
      expect(post.errors[:video_block_id]).to be_present
    end

    it 'rejects a block from another platform' do
      other = create(:better_together_platform)
      video_block.update_columns(platform_id: other.id)
      post.video_block_id = video_block.id

      expect(post).not_to be_valid
    end

    it 'ignores the block id on update' do
      post.save!
      post.update!(video_block_id: video_block.id)

      expect(attached_blocks(post)).to be_empty
    end

    it 'renders a public portrait block in a 9x16 frame', :aggregate_failures do
      video_block.seed_privacy_ceiling_exempt = true
      video_block.update!(privacy: 'public', aspect_ratio: '9x16')
      post.video_block_id = video_block.id
      post.save!

      expect(render_body(post)).to include('youtube-nocookie.com/embed/dQw4w9WgXcQ', 'ratio-9x16')
    end

    it 'holds the video while the block is not public' do
      post.video_block_id = video_block.id
      post.save!

      expect(render_body(post)).to include('held-review')
    end
  end

  describe 'attachment_block_ids' do # rubocop:disable RSpec/MultipleMemoizedHelpers
    let(:png) do
      Base64.strict_decode64(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=='
      )
    end
    let(:image_block) do
      BetterTogether::Content::Image.create!(platform:, privacy: 'private', identifier: 'ab-img', creator: person,
                                             caption: 'Sunrise, 07:38', media_data: Base64.strict_encode64(png),
                                             media_filename: 'sunrise.png')
    end

    def attachables(record)
      BetterTogether::Post.find(record.id).content.body.attachables
    end

    it 'attaches image blocks ahead of the description', :aggregate_failures do
      post.assign_attributes(content: 'Sunrise over Corner Brook', attachment_block_ids: [image_block.id])
      post.save!

      expect(attachables(post)).to eq([image_block])
      expect(post.reload.content.body.to_html).to match(/\A<action-text-attachment.*Sunrise over Corner Brook/m)
    end

    it 'attaches the video block first, then the images, in order', :aggregate_failures do
      post.assign_attributes(video_block_id: video_block.id, attachment_block_ids: [image_block.id])
      post.save!

      expect(attachables(post)).to eq([video_block, image_block])
    end

    it 'rejects an unknown block id', :aggregate_failures do
      post.attachment_block_ids = [SecureRandom.uuid]

      expect(post).not_to be_valid
      expect(post.errors[:attachment_block_ids]).to be_present
    end

    it 'rejects blocks of other types' do
      other = BetterTogether::Content::Markdown.create!(platform:, privacy: 'private', identifier: 'ab-md',
                                                        creator: person, markdown_source: '# Heading')
      post.attachment_block_ids = [other.id]

      expect(post).not_to be_valid
    end

    it 'leaves the body alone on an update that sends no ids', :aggregate_failures do
      post.update!(content: 'First', attachment_block_ids: [image_block.id])
      post.update!(title: 'Renamed')

      expect(attachables(post).map(&:id)).to eq([image_block.id])
      expect(post.reload.content.body.to_html).to include('First')
    end

    it 'replaces the text on update and puts the images back in front of it', :aggregate_failures do # rubocop:disable RSpec/ExampleLength
      post.update!(content: 'Arrived', attachment_block_ids: [image_block.id])
      post.update!(content: 'In port 8:42 AM to 4:42 PM', attachment_block_ids: [image_block.id])

      expect(attachables(post).map(&:id)).to eq([image_block.id])
      body = post.reload.content.body.to_html
      expect(body).to match(/\A<action-text-attachment.*In port 8:42 AM/m)
      expect(body).not_to include('Arrived')
    end

    it 'keeps the image blocks when only new text is sent', :aggregate_failures do # rubocop:disable RSpec/ExampleLength
      post.update!(content: 'Arrived', attachment_block_ids: [image_block.id])
      post = BetterTogether::Post.find(self.post.id)
      post.update!(content: 'In port 8:42 AM to 4:42 PM')

      expect(attachables(post).map(&:id)).to eq([image_block.id])
      body = post.reload.content.body.to_html
      expect(body).to match(/\A<action-text-attachment.*In port 8:42 AM/m)
      expect(body).not_to include('Arrived')
    end

    it 'rejects an unknown block id on update' do
      post.save!

      expect(post.update(attachment_block_ids: [SecureRandom.uuid])).to be(false)
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

    it 'accepts the contributors as a JSON string, as the JSON:API sends them', :aggregate_failures do
      plain_post.contributor_specs = [
        { author_type: 'BetterTogether::Robot', author_id: robot.id, role: 'author', position: 0 }
      ].to_json
      plain_post.save!

      expect(plain_post.reload.contributions.pluck(:author_type, :role)).to eq([['BetterTogether::Robot', 'author']])
    end

    it 'rejects unsupported contributor types' do
      plain_post.contributor_specs = [{ author_type: 'BetterTogether::Community', author_id: 'x' }]

      expect(plain_post).not_to be_valid
    end
  end
end
