# frozen_string_literal: true

require 'rails_helper'

# The meetings tab must not run more queries as the council holds more meetings.
RSpec.describe 'Municipal meetings query scaling', type: :request do
  include RequestSpecHelper

  let(:path) { "/#{I18n.default_locale}/e/municipalities/nl/corner-brook/meetings" }

  before do
    configure_host_platform.update!(privacy: 'public')
    corner_brook_council
    import_meetings
    get path
  end

  def query_count
    count = 0
    counter = ->(*, payload) { count += 1 unless %w[SCHEMA TRANSACTION].include?(payload[:name]) || payload[:cached] }
    ActiveSupport::Notifications.subscribed(counter, 'sql.active_record') { get path }
    expect(response).to have_http_status(:ok)
    count
  end

  def add_meetings(total)
    extra = Array.new(total) do |i|
      fixture_meetings.first.merge(source_id: "bulk-#{i}", starts_at: (i + 1).days.ago, title: "Meeting #{i}",
                                   body_type: i.even? ? 'Regular Meeting' : 'Committee of the Whole')
    end
    import_meetings(meetings: extra)
  end

  it 'does not add queries as meetings are added' do
    small = query_count
    add_meetings(12)

    expect(query_count).to be <= small + 2
  end
end
