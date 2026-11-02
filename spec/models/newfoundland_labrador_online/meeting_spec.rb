# frozen_string_literal: true

require 'rails_helper'

RSpec.describe NewfoundlandLabradorOnline::Meeting do
  include RequestSpecHelper

  before do
    configure_host_platform
    corner_brook_council
    import_meetings
  end

  it 'orders newest first and separates upcoming from past' do
    meetings = described_class.newest_first.to_a

    expect(meetings.map(&:starts_at)).to eq(meetings.map(&:starts_at).sort.reverse)
  end

  it 'rejects an unknown kind or status and a duplicate source id', :aggregate_failures do
    existing = described_class.first
    expect(existing.dup.tap { |m| m.kind = 'wat' }).not_to be_valid
    expect(existing.dup.tap { |m| m.status = 'wat' }).not_to be_valid
    expect(existing.dup).not_to be_valid
  end

  it 'only accepts https document links' do
    document = described_class.first.documents.build(kind: 'agenda', format: 'pdf', title: 'x', url: 'http://a.example/x.pdf')

    expect(document).not_to be_valid
  end

  it 'gives categories a readable text color' do
    colors = described_class.all.filter_map(&:category).uniq.to_h { |c| [c.identifier, c.chip_text_color] }

    expect(colors).to eq('meeting-regular' => '#ffffff', 'meeting-committee_of_the_whole' => '#111111')
  end
end
