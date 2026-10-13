# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'better_together/posts/_video_embed', type: :view do
  let(:platform) { BetterTogether::Platform.find_by(host: true) || create(:better_together_platform) }
  let(:post) do
    BetterTogether::Post.new(title: 'Daily timelapse', content: 'Video', identifier: 'cbo-view-1', platform:,
                             privacy: 'private')
  end

  before { view.extend(BetterTogether::Content::BlocksHelper) }

  it 'renders nothing without a video url' do
    render partial: 'better_together/posts/video_embed', locals: { post: }

    expect(rendered.strip).to be_empty
  end

  it 'renders a privacy-enhanced iframe in a 16x9 frame for landscape videos' do
    post.video_url = 'https://www.youtube.com/watch?v=dQw4w9WgXcQ'
    post.video_orientation = 'landscape'

    render partial: 'better_together/posts/video_embed', locals: { post: }

    expect(rendered).to include('youtube-nocookie.com/embed/dQw4w9WgXcQ', 'ratio-16x9', 'post-video--landscape')
  end

  it 'renders portrait videos in a 9x16 frame' do
    post.video_url = 'https://www.youtube.com/shorts/dQw4w9WgXcQ'
    post.video_orientation = 'portrait'

    render partial: 'better_together/posts/video_embed', locals: { post: }

    expect(rendered).to include('ratio-9x16', 'post-video--portrait')
  end
end
