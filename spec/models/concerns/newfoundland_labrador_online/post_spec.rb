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
    let(:embed) { NewfoundlandLabradorOnline::VideoEmbed.new(youtube_id: 'dQw4w9WgXcQ', orientation: 'landscape') }

    def attached_embeds(record)
      record.reload.content.body.attachables.grep(NewfoundlandLabradorOnline::VideoEmbed)
    end

    it 'puts the video attachment ahead of the description', :aggregate_failures do
      post.content = 'Daily timelapse description'
      post.save!

      expect(attached_embeds(post)).to eq([embed])
      expect(post.content.body.to_html).to match(/\A<action-text-attachment.*Daily timelapse description/m)
    end

    it 'uses the post orientation for the attachment' do
      post.video_url = 'https://www.youtube.com/shorts/dQw4w9WgXcQ'
      post.video_orientation = 'portrait'
      post.save!

      expect(attached_embeds(post).first.orientation).to eq('portrait')
    end

    it 'does not duplicate the attachment when saved again' do
      post.save!
      post.update!(title: 'Renamed')

      expect(attached_embeds(post).size).to eq(1)
    end

    it 'replaces the attachment when the video changes', :aggregate_failures do
      post.save!
      post.update!(video_url: 'https://www.youtube.com/watch?v=abcdefghijk')

      expect(attached_embeds(post).map(&:youtube_id)).to eq(%w[abcdefghijk])
      expect(post.content.body.to_html).to include('<action-text-attachment').once
    end

    it 'renders the iframe from the saved body', :aggregate_failures do
      post.save!
      html = BetterTogether::PostsController.render(inline: '<%= render_action_text_content(c) %>',
                                                    locals: { c: post.reload.content.body })

      expect(html).to include('youtube-nocookie.com/embed/dQw4w9WgXcQ', 'ratio-16x9')
    end

    it 'reads video_url and video_orientation back from the attachment', :aggregate_failures do
      post.assign_attributes(video_url: 'https://www.youtube.com/shorts/dQw4w9WgXcQ', video_orientation: 'portrait')
      post.save!
      reloaded = BetterTogether::Post.find(post.id)

      expect(reloaded).to have_attributes(video_url: 'https://www.youtube.com/shorts/dQw4w9WgXcQ',
                                          video_orientation: 'portrait')
    end

    it 'does not store video_url in display_settings' do
      post.save!

      expect(post.reload.display_settings.keys).not_to include('video_url', 'video_orientation')
    end

    it 'does not re-add a video an editor removed from the body', :aggregate_failures do
      post.save!
      post = BetterTogether::Post.find(self.post.id)
      post.update!(content: '<div>Text only</div>')

      expect(attached_embeds(post)).to be_empty
      expect(post.video_url).to be_nil
    end

    it 'changes only the orientation when given no new url', :aggregate_failures do
      post.save!
      reloaded = BetterTogether::Post.find(post.id)
      reloaded.update!(video_orientation: 'portrait')

      expect(attached_embeds(reloaded).map(&:id)).to eq(['dQw4w9WgXcQ:portrait'])
    end

    it 'adds no attachment without a video url' do
      post.video_url = nil
      post.save!

      expect(attached_embeds(post)).to be_empty
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
