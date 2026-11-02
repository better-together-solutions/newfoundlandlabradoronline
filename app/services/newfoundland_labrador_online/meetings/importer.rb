# frozen_string_literal: true

require 'digest'

module NewfoundlandLabradorOnline
  module Meetings
    # Writes normalised meetings (see EscribeSource) as Meeting, MeetingDocument and a public Event hosted by the
    # council community. Idempotent by (source, source_id); an unchanged meeting is left alone. Dry unless apply: true.
    class Importer
      Result = Struct.new(:created, :updated, :unchanged, :missing_bodies, keyword_init: true) do
        def counts = { created:, updated:, unchanged: }
      end

      DEFAULT_DURATION_MINUTES = 120

      def initialize(source_key:, config:, meetings:, apply: false)
        @source_key = source_key
        @config = config
        @meetings = meetings
        @apply = apply
        @result = Result.new(created: 0, updated: 0, unchanged: 0, missing_bodies: [])
      end

      def call
        council = council_community
        return missing(council) unless council

        @meetings.each { |meeting| import(council, meeting) }
        @result
      end

      private

      def missing(_council)
        @result.missing_bodies << @config.fetch('council')
        @result
      end

      def council_community
        settlement = BetterTogether::Geography::Settlement.friendly.find(@config.fetch('council'))
        Civic::Municipality.for(settlement)&.council
      rescue ActiveRecord::RecordNotFound
        nil
      end

      def import(council, data)
        checksum = Digest::SHA256.hexdigest(JSON.generate(data.sort_by { |key, _| key.to_s }))
        meeting = Meeting.find_by(source: @source_key, source_id: data[:source_id])
        return @result.unchanged += 1 if meeting&.source_checksum == checksum

        meeting ? @result.updated += 1 : @result.created += 1
        write(council, data, meeting, checksum) if @apply
      end

      def write(council, data, meeting, checksum)
        Meeting.transaction do
          meeting ||= Meeting.new(source: @source_key, source_id: data[:source_id])
          meeting.update!(attributes_for(council, data, checksum))
          sync_documents(meeting, data[:documents])
          meeting.update!(event: write_event(meeting, council, data))
        end
      end

      def attributes_for(council, data, checksum)
        body = @config.fetch('bodies').fetch(data[:body_type]) { unknown_body(data[:body_type]) }
        { body: council, kind: body['kind'], body_key: body['key'], title: data[:title], starts_at: data[:starts_at],
          location: data[:location], status: status_for(data), portal_url: data[:portal_url],
          source_checksum: checksum, fetched_at: Time.current }
      end

      def unknown_body(type)
        { 'key' => type.parameterize, 'kind' => 'committee', 'name' => type }
      end

      def status_for(data)
        return 'cancelled' if data[:status] == 'cancelled'

        data[:starts_at] < Time.current ? 'held' : 'scheduled'
      end

      def sync_documents(meeting, documents)
        wanted = documents.map { |doc| doc.values_at(:kind, :format, :url) }
        meeting.documents.reject { |doc| wanted.include?(doc.attributes.values_at('kind', 'format', 'url')) }
               .each(&:destroy!)
        documents.each do |doc|
          meeting.documents.find_or_initialize_by(doc.slice(:kind, :format, :url)).update!(title: doc[:title])
        end
      end

      def write_event(meeting, council, data)
        platform = BetterTogether::Platform.find_by!(host: true)
        event = BetterTogether::Event.find_or_initialize_by(platform:, source_id: "#{@source_key}:#{data[:source_id]}")
        event.assign_attributes(event_attributes(meeting, data))
        event.event_hosts.build(host: council) if event.new_record?
        event.save!
        event.categories = [category_for(platform, data[:body_type])]
        event
      end

      def event_attributes(meeting, data)
        { name: meeting.title.presence || data[:body_type], starts_at: meeting.starts_at,
          duration_minutes: DEFAULT_DURATION_MINUTES, timezone: @config.fetch('time_zone'), privacy: 'public',
          status: meeting.cancelled? ? 'cancelled' : 'confirmed', source_updated_at: Time.current,
          description: meeting.location.to_s }
      end

      def category_for(platform, body_type)
        body = @config.fetch('bodies').fetch(body_type) { unknown_body(body_type) }
        MeetingCategory.find_or_initialize_by(platform:, identifier: "meeting-#{body['key']}").tap do |category|
          next unless category.new_record?

          category.assign_attributes(name: body['name'] || body_type, icon: body['icon'] || MeetingCategory::DEFAULT_ICON,
                                     color: body['color'] || MeetingCategory::DEFAULT_COLOR)
          category.save!
        end
      end
    end
  end
end
