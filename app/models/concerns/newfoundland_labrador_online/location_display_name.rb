# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # CE shows a location by its name alone, so a named place at a street address ("Rotary Arts Centre") hides where
  # it is. Event cards, event pages and map popups all print the display name, so it carries the address too.
  module LocationDisplayName
    def display_name
      base = super
      return base unless name.present? && address?

      street = location.to_formatted_s(excluded: [:display_label])
      street.present? ? "#{base}, #{street}" : base
    end
  end
end
