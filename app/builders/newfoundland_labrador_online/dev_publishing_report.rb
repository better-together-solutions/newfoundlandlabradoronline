# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # Local-only: what the Corner Brook Online publisher created, one entry per yt- post, for
  # verifying an end-to-end run (see rake nlo:dev:cbo_e2e_report).
  class DevPublishingReport
    def call
      ::BetterTogether::Post.where('identifier LIKE ?', 'yt-%').order(:identifier).map { |post| entry(post) }
    end

    private

    def entry(post)
      post.slice(:identifier, :title, :privacy).symbolize_keys.merge(
        published: post.published_at.present?, community: post.community&.identifier,
        categories: post.categories.map(&:identifier).sort, contributors: contributors(post), blocks: blocks(post)
      )
    end

    def contributors(post)
      post.contributions.map { |contribution| [contribution.author_type.demodulize, contribution.role] }.sort
    end

    def blocks(post)
      post.content.body.attachables.grep(::BetterTogether::Content::VideoBlock).map do |block|
        block.slice(:video_url, :aspect_ratio, :privacy).symbolize_keys
      end
    end
  end
end
