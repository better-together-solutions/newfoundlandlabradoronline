# frozen_string_literal: true

require 'json'

module NewfoundlandLabradorOnline
  module Civic
    # Loads a municipality's published organisational contact details (addresses, phone numbers, email addresses and
    # social accounts, all CE records) onto its council's contact detail, from an offline packet
    # (db/data/nl_municipal). Organisation details only, never individual staff or councillors. A dry run (the
    # default) rolls everything back, so the counts are what an apply would do. Idempotent: each record is matched on
    # its natural key, and a changed value updates in place. Everything loaded is public.
    class MunicipalContactLoader
      DEFAULT_PATH = Rails.root.join('db/data/nl_municipal/contact_details.json')
      # Association on the contact detail => the attribute that identifies a record within it.
      KINDS = { 'addresses' => 'line1', 'phone_numbers' => 'number', 'email_addresses' => 'email',
                'social_media_accounts' => 'platform_name' }.freeze
      Result = Struct.new(:created, :updated, :unchanged, :missing_councils, keyword_init: true)

      def initialize(path: DEFAULT_PATH, apply: false)
        @path = path
        @apply = apply
        @result = Result.new(created: [], updated: [], unchanged: [], missing_councils: [])
      end

      def call
        entries = JSON.parse(File.read(@path)).fetch('contacts')
        ActiveRecord::Base.transaction do
          Civic.in_platform_zone { entries.each { |entry| load_contact(entry) } }
          raise ActiveRecord::Rollback unless @apply
        end
        @result
      end

      private

      def load_contact(entry)
        slug = entry.fetch('settlement')
        council = council_for(slug)
        return @result.missing_councils << slug unless council

        KINDS.each do |kind, key|
          entry.fetch(kind, []).each { |attrs| upsert(council.contact_detail.public_send(kind), key, attrs, slug) }
        end
      end

      def upsert(records, key, attrs, slug)
        record = records.find_or_initialize_by(key => attrs.fetch(key))
        record.assign_attributes(attrs.merge('privacy' => 'public'))
        bucket = bucket_for(record)
        record.save! unless bucket == :unchanged
        @result[bucket] << "#{slug}/#{attrs.fetch(key)}"
      end

      def bucket_for(record)
        return :created if record.new_record?

        record.changed? ? :updated : :unchanged
      end

      def council_for(slug)
        settlement = BetterTogether::Geography::Settlement.friendly.find(slug)
        council = Municipality.for(settlement)&.council
        council&.tap { |community| community.create_contact_detail! if community.contact_detail.nil? }
      rescue ActiveRecord::RecordNotFound
        nil
      end
    end
  end
end
