# frozen_string_literal: true

require 'digest'
require 'json'
require 'net/http'

module NewfoundlandLabradorOnline
  module Civic
    # Downloads a council's ward polygons from a public ArcGIS layer as WGS84 GeoJSON and writes the offline packet the
    # WardBoundaryLoader reads. Read-only against the source; the packet records the authority, the layer and portal
    # URLs, the fetch date and a checksum of the response. Stays dry (prints, writes nothing) unless write: true.
    class WardBoundaryFetcher
      LAYER_URL = 'https://map.stjohns.ca/mapsrv/rest/services/Mapcentre/Administrative_Boundaries/MapServer/2'
      PORTAL_URL = 'https://map.stjohns.ca/mapsrv/rest/services/Mapcentre/Administrative_Boundaries/MapServer'
      AUTHORITY = "City of St. John's"
      SETTLEMENT = 'st-john-s'
      TIMEOUT = 30

      def initialize(path: WardBoundaryLoader::DEFAULT_PATH, write: false)
        @layer_url = LAYER_URL
        @portal_url = PORTAL_URL
        @authority = AUTHORITY
        @settlement = SETTLEMENT
        @path = path
        @write = write
      end

      def call
        body = fetch
        packet = build(body)
        File.write(@path, "#{JSON.generate(packet)}\n") if @write
        packet
      end

      def query_url
        "#{@layer_url}/query?where=1%3D1&outFields=WARD%2CWARDNAME&returnGeometry=true&outSR=4326&f=geojson"
      end

      private

      def fetch
        uri = URI(query_url)
        response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: TIMEOUT,
                                                       read_timeout: TIMEOUT) { |http| http.get(uri.request_uri) }
        raise "ward layer returned HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

        response.body
      end

      def build(body)
        parsed = JSON.parse(body)
        raise "ward layer error: #{parsed['error']}" if parsed['error']

        sha = Digest::SHA256.hexdigest(body)
        features = parsed.fetch('features').map { |feature| packet_feature(feature, sha) }
        raise 'ward layer returned no features' if features.empty?

        { 'type' => 'FeatureCollection', 'features' => features.sort_by { |f| f['properties']['seat'] } }
      end

      def packet_feature(feature, sha)
        props = feature.fetch('properties')
        { 'type' => 'Feature', 'geometry' => feature.fetch('geometry'),
          'properties' => { 'settlement' => @settlement, 'seat' => "Ward #{props.fetch('WARD')}",
                            'authority' => @authority, 'source_url' => @layer_url, 'portal_url' => @portal_url,
                            'license' => nil, 'source_sha256' => sha, 'fetched_on' => Time.zone.today.iso8601 } }
      end
    end
  end
end
