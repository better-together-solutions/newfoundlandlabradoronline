# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # Builds the map for a geospatial listing page from the records the page lists.
  module ListingMapHelper
    DEFAULT_TOLERANCE = 0.005

    # kind names the listing ('districts', 'settlements'); url_for maps a record to its page; popup_body maps a record
    # to the HTML under the popup title (the default shows the record type and a description excerpt). overlay_for maps
    # a record to { color:, popup: } to draw its area filled in that colour.
    # rubocop:disable-next Metrics/ParameterLists
    def listing_map(records, kind:, url_for: nil, popup_body: nil, tolerance: DEFAULT_TOLERANCE, overlay_for: nil)
      list = records.to_a
      ActiveRecord::Associations::Preloader.new(records: list, associations: :space).call
      NewfoundlandLabradorOnline::ListingMap.find_or_initialize_by(identifier: "listing-#{kind}").tap do |map|
        map.records = list
        map.tolerance = tolerance
        map.url_for = url_for || ->(record) { polymorphic_path(record, locale: I18n.locale) }
        map.popup_body = popup_body || method(:default_popup_body)
        map.overlay_for = overlay_for
      end
    end

    private

    def default_popup_body(record)
      type = ERB::Util.html_escape(record.class.model_name.human)
      excerpt = ERB::Util.html_escape(record.try(:description).to_s.truncate(140))
      "<p class='mb-1 text-muted'>#{type}</p>#{"<p class='mb-0'>#{excerpt}</p>" if excerpt.present?}"
    end
  end
end
