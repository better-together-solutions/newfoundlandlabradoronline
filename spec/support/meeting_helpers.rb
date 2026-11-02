# frozen_string_literal: true

# Builds a Corner Brook style council and imports the sanitized eScribe fixture into it.
module MeetingHelpers
  def corner_brook_council
    province = BetterTogether::Geography::State.find_by!(iso_code: 'CA-NL')
    create(:geography_settlement, identifier: 'corner-brook', name: 'Corner Brook', state: province)
    NewfoundlandLabradorOnline::Civic::MunicipalRosterLoader.new(apply: true).call
  end

  def meeting_config
    YAML.load_file(Rails.root.join('config/meetings/sources.yml')).fetch('cornerbrook')
        .merge('portal' => 'https://pub-example.escribemeetings.com')
  end

  def fixture_meetings
    body = Rails.root.join('spec/fixtures/meetings/escribe_calendar.json').read
    NewfoundlandLabradorOnline::Meetings::EscribeSource.new(meeting_config).parse(body)
  end

  def import_meetings(apply: true, meetings: fixture_meetings)
    NewfoundlandLabradorOnline::Meetings::Importer.new(source_key: 'cornerbrook', config: meeting_config,
                                                       meetings:, apply:).call
  end
end

RSpec.configure { |config| config.include MeetingHelpers }
