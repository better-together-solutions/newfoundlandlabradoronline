# frozen_string_literal: true

require 'json'

module NewfoundlandLabradorOnline
  module Civic
    # Attaches a municipality's public social accounts (CE SocialMediaAccount) to its council's contact detail, from
    # an offline packet (db/data/nl_municipal). A dry run (the default) rolls everything back, so the counts are what
    # an apply would do. Idempotent: accounts are matched on council and platform.
    class MunicipalSocialAccountLoader
      DEFAULT_PATH = Rails.root.join('db/data/nl_municipal/social_accounts.json')
      Result = Struct.new(:created, :updated, :unchanged, :missing_councils, keyword_init: true)

      def initialize(path: DEFAULT_PATH, apply: false)
        @path = path
        @apply = apply
        @result = Result.new(created: [], updated: [], unchanged: [], missing_councils: [])
      end

      def call
        entries = JSON.parse(File.read(@path)).fetch('accounts')
        ActiveRecord::Base.transaction do
          Civic.in_platform_zone { entries.each { |entry| load_account(entry) } }
          raise ActiveRecord::Rollback unless @apply
        end
        @result
      end

      private

      def load_account(entry)
        council = council_for(entry.fetch('settlement'))
        return @result.missing_councils << entry.fetch('settlement') unless council

        accounts = council.contact_detail.social_media_accounts
        account = accounts.find_or_initialize_by(platform_name: entry.fetch('platform'))
        label = "#{entry.fetch('settlement')}/#{account.platform_name}"
        account.assign_attributes(handle: entry['handle'], url: entry.fetch('url'), privacy: 'public')
        record(account, label)
      end

      def record(account, label)
        bucket = if account.new_record? then :created
                 elsif account.changed? then :updated
                 else :unchanged
                 end
        account.save! unless bucket == :unchanged
        @result[bucket] << label
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
