# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # The kind of body a meeting belongs to (Regular Council Meeting, an advisory committee, ...), as an event category
  # with an icon and a colour. One record per body, so events and meetings share the filter.
  class MeetingCategory < BetterTogether::EventCategory
    DEFAULT_ICON = 'fas fa-calendar-day'
    DEFAULT_COLOR = '#6B6B6B'

    before_validation { self.icon = DEFAULT_ICON if icon.blank? }
    validates :color, format: { with: /\A#\h{6}\z/ }, allow_blank: true

    # White or near-black, whichever reads better on the colour.
    def chip_text_color = ColorContrast.text_color_for(color.presence || DEFAULT_COLOR)
    def chip_color = color.presence || DEFAULT_COLOR
  end
end
