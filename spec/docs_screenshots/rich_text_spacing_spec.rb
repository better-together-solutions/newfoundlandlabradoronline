# frozen_string_literal: true

require 'rails_helper'

# Rich text written as paragraphs (API, import) spaces like text written in the editor.
#
#   RUN_DOCS_SCREENSHOTS=1 ./bin/dc-run bundle exec rspec spec/docs_screenshots/rich_text_spacing_spec.rb
RSpec.describe 'Documentation screenshots for rich text spacing', :js, type: :feature do
  include RequestSpecHelper

  let(:html) do
    '<p>First paragraph of the description.</p><p>Second paragraph follows.</p><h2>Hours</h2>' \
      '<ul><li>Box office: Monday to Friday</li><li>Galleries: Monday to Friday</li></ul><p>Closing note.</p>'
  end
  let(:event) do
    create(:better_together_event, privacy: 'public', starts_at: 3.days.from_now, ends_at: 3.days.from_now + 2.hours,
                                   description: html)
  end

  before do
    skip 'set RUN_DOCS_SCREENSHOTS=1 to capture documentation screenshots' unless ENV['RUN_DOCS_SCREENSHOTS']

    configure_host_platform.update!(privacy: 'public')
  end

  it 'captures paragraph spacing on an event description' do
    visit "/#{I18n.default_locale}/events/#{event.slug}"
    callouts = [{ selector: '.trix-content', title: 'Spaced' }]
    paths = DocsScreenshots.capture(page, 'rich_text_spacing', callouts:)

    expect(paths.map { |path| File.size(path) }).to all(be > 10_000)
  end
end
