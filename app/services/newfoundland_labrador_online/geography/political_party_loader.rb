# frozen_string_literal: true

require 'json'

module NewfoundlandLabradorOnline
  module Geography
    # Loads provincial parties (name, brand colour, logo with its licence) from the offline packet built by
    # management-tool scripts/nl_parties_ingest.py. Idempotent; a logo is attached once and replaced only when the
    # file's content changes.
    class PoliticalPartyLoader
      DEFAULT_PATH = Rails.root.join('db/data/nl_regions/provincial_parties.json')
      LOGO_DIR = Rails.root.join('db/data/nl_regions/party_logos')
      Result = Struct.new(:created, :updated, keyword_init: true)

      def initialize(path: DEFAULT_PATH, logo_dir: LOGO_DIR)
        @path = path
        @logo_dir = logo_dir
        @result = Result.new(created: [], updated: [])
      end

      def call
        JSON.parse(File.read(@path)).fetch('parties').each { |entry| load_party(entry) }
        @result
      end

      private

      def load_party(entry)
        party = PoliticalParty.find_or_initialize_by(jurisdiction: entry.fetch('jurisdiction'),
                                                     identifier: entry.fetch('key'))
        bucket = party.new_record? ? @result.created : @result.updated
        party.update!(attributes_for(entry))
        attach_logo(party, entry['logo_file'])
        bucket << party.identifier
      end

      def attributes_for(entry)
        { name: entry.fetch('name'), short_name: entry.fetch('short_name'), color: entry['color'],
          color_source: entry['color_source'], wikipedia_page: entry['wikipedia_page'],
          logo_source_url: entry['logo_source_url'], logo_license: entry['logo_license'],
          logo_non_free: entry['logo_non_free'] }
      end

      def attach_logo(party, file_name)
        return unless file_name

        path = @logo_dir.join(file_name)
        checksum = OpenSSL::Digest::MD5.file(path).base64digest
        return if party.logo.attached? && party.logo.blob.checksum == checksum

        party.logo.attach(io: File.open(path), filename: file_name, content_type: Marcel::MimeType.for(path))
      end
    end
  end
end
