# frozen_string_literal: true

module NewfoundlandLabradorOnline
  module Meetings
    # Video providers a meeting recording can come from. A provider turns a link into the provider's reference and the
    # links the page needs, and names the origin its player is framed from.
    module VideoProvider
      PROVIDERS = { 'youtube' => 'NewfoundlandLabradorOnline::Meetings::VideoProvider::Youtube' }.freeze

      # The provider key and reference for a link, or nil when no provider recognises it.
      def self.identify(url)
        PROVIDERS.each_value do |class_name|
          provider = class_name.constantize
          ref = provider.reference_from(url)
          return provider if ref
        end
        nil
      end
    end
  end
end
