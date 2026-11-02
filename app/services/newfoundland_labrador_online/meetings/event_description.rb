# frozen_string_literal: true

module NewfoundlandLabradorOnline
  module Meetings
    # Rich text for a council meeting's event: the meeting card (an Action Text attachment, so it carries the location
    # and portal documents) and a link to the council's full meeting list. A recording is attached as a video block
    # after this text by the importer.
    class EventDescription
      def initialize(meeting, settlement)
        @meeting = meeting
        @settlement = settlement
      end

      def to_html
        card = ActionText::Attachment.from_attachable(@meeting).to_html
        "#{card}<p><a href=\"#{listing_path}\">#{ERB::Util.h(listing_label)}</a></p>"
      end

      private

      def listing_path
        code = Province.code_for(@settlement.state)
        Rails.application.routes.url_helpers.newfoundland_labrador_online_municipality_meetings_path(
          code, @settlement, locale: I18n.default_locale
        )
      end

      def listing_label
        I18n.t('newfoundland_labrador_online.municipal_meetings.index.all_meetings', name: @settlement.name)
      end
    end
  end
end
