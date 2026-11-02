# frozen_string_literal: true

require 'cgi'
require 'json'
require 'net/http'

module NewfoundlandLabradorOnline
  module Meetings
    # Reads the public calendar of an eScribe portal (one JSON request for any date range) and normalises each meeting.
    # Read only. Documents stay on the portal; only their links are returned.
    class EscribeSource
      CALENDAR_PATH = '/MeetingsCalendarView.aspx/GetCalendarMeetings'
      USER_AGENT = 'Mozilla/5.0 (compatible; BTS-NLO-meetings; +https://newfoundlandlabrador.online)'
      TIMEOUT = 30
      DOCUMENT_KINDS = { 'AgendaCover' => 'agenda', 'Agenda' => 'agenda_package', 'PostAgenda' => 'agenda_package',
                         'PostMinutes' => 'minutes', 'AdditionalDocuments' => 'additional' }.freeze
      FORMATS = { '.pdf' => 'pdf', 'HTML' => 'html' }.freeze

      def initialize(config)
        @portal = config.fetch('portal').chomp('/')
        @zone = ActiveSupport::TimeZone[config.fetch('time_zone')]
      end

      def fetch(from:, to:)
        parse(request(from, to))
      end

      # Normalises the portal's JSON body into meeting hashes, oldest first.
      def parse(body)
        rows = JSON.parse(body).fetch('d')
        rows.map { |row| normalise(row) }.sort_by { |meeting| meeting[:starts_at] }
      end

      private

      def request(from, to)
        uri = URI("#{@portal}#{CALENDAR_PATH}")
        payload = "{'calendarStartDate':'#{from.iso8601}','calendarEndDate':'#{to.iso8601}'}"
        response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: TIMEOUT,
                                                       read_timeout: TIMEOUT) do |http|
          http.post(uri.request_uri, payload, 'Content-Type' => 'application/json', 'User-Agent' => USER_AGENT)
        end
        raise "eScribe returned HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

        response.body
      end

      def normalise(row)
        title = CGI.unescapeHTML(row.fetch('MeetingName')).squish
        { source_id: row.fetch('ID'), title:, body_type: CGI.unescapeHTML(row.fetch('MeetingType')).squish,
          starts_at: starts_at(row.fetch('StartDate')), location: row['Location'].presence,
          portal_url: portal_url(row),
          status: status_for(title),
          **links(row['MeetingDocumentLink']) }
      end

      def links(links) = { documents: documents(links), video_urls: video_urls(links) }

      def status_for(title) = title.match?(/cancel/i) ? 'cancelled' : 'scheduled'

      def portal_url(row)
        row['Url'].presence || "#{@portal}/Meeting.aspx?Id=#{row['ID']}&Agenda=Agenda&lang=English"
      end

      # eScribe stamps meaningless seconds on the time; keep the minute.
      def starts_at(text)
        @zone.parse(text.tr('/', '-')).change(sec: 0)
      end

      def documents(links)
        found = Array(links).filter_map { |link| document(link) }
        found.uniq { |doc| doc.values_at(:kind, :format, :url) }
      end

      def document(link)
        kind = DOCUMENT_KINDS[link['Type']]
        format = FORMATS[link['Format']]
        url = absolute(link['Url'])
        { kind:, format:, title: link['Title'], url: } if kind && format && url
      end

      def video_urls(links)
        Array(links).select { |link| link['Type'] == 'Video' }.filter_map { |link| absolute(link['Url']) }
      end

      def absolute(path)
        return if path.blank?

        url = URI.join("#{@portal}/", path).to_s
        url if url.start_with?('https://')
      end
    end
  end
end
