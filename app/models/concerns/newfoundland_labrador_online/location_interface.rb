# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # The location interface shared by every locatable record (see LocatableModels): reading and
  # setting the location by settlement identifier, `located_in` scopes, and the effective location
  # (the record's own, else the one it inherits). It assumes `location` is a has_one LocatableLocation.
  # Models that already have CE's Locatable::One (events) include only this; others include Locatable.
  module LocationInterface
    extend ActiveSupport::Concern

    SETTLEMENT = 'BetterTogether::Geography::Settlement'
    ADDRESS_FIELDS = %w[name line1 line2 city_name state_province_name postal_code country_name].freeze
    ADDRESS_MATCH_FIELDS = %w[line1 city_name postal_code country_name].freeze

    included do
      class_attribute :location_inheritance, instance_accessor: false
      validate :settlement_identifier_must_exist
      validate :address_data_must_be_valid
    end

    class_methods do
      # Records located in +place+ (a settlement, region, address, ...). A record with its own location
      # counts only through that location; a record without one counts through the location of the
      # record it inherits from (see Locatable.inherit_location_from).
      def located_in(place)
        direct = where(id: LocationQueries.locatable_ids(self, place))
        inherited = inherited_located_in(place)
        inherited ? direct.or(inherited) : direct
      end

      private

      def inherited_located_in(place)
        reflection = location_inheritance && reflect_on_association(location_inheritance)
        return unless reflection

        parent_ids = reflection.klass.located_in(place).select(:id)
        where.not(id: LocationQueries.explicitly_located_ids(self)).where(reflection.foreign_key => parent_ids)
      end
    end

    # The settlement identifier when the record is located at a settlement, else nil.
    def settlement_identifier
      place = location&.location
      place.identifier if place && place.class.base_class.name == SETTLEMENT
    end

    # Locates the record at the settlement with this identifier; blank clears the location.
    def settlement_identifier=(value)
      @settlement_identifier_error = nil
      if value.blank?
        clear_location
      elsif (settlement = SETTLEMENT.constantize.find_by(identifier: value.to_s.strip.downcase))
        (location || build_location).location = settlement
      else
        @settlement_identifier_error = value.to_s
      end
    end

    # Write-only API input: locates the record at a street address, given as a hash or a JSON string (the JSON:API
    # rejects nested objects) with line1, line2, city_name, state_province_name, postal_code and country_name. An
    # existing address with the same line1, city, postal code and country is reused; otherwise a public one is
    # created. CE then places the address in the settlement whose boundary contains it. Blank clears the location.
    def address_data
      nil
    end

    def address_data=(spec)
      @address_data_error = nil
      if spec.blank?
        clear_location
      else
        locate_at_address(spec)
      end
    rescue JSON::ParserError
      @address_data_error = 'is not valid JSON'
    end

    # The map point for the record's own location when it has coordinates (an address or building with a geocoded
    # space), as an array of zero or one, in the shape CE's maps use plus type, color and icon for typed pins. Names
    # are user supplied, so they are HTML escaped. Separate from #leaflet_points so a model that already defines it
    # (a community's building points) is left alone.
    def located_leaflet_point
      point = location&.location&.to_leaflet_point
      return [] unless point

      link = located_link
      [point.merge(label: link, popup_html: "#{link}<br>#{ERB::Util.html_escape(location.display_name)}",
                   **located_map_style)]
    end

    # The record's own place, else the place it inherits, else nil. A location that is only free text
    # still counts as the record's own, so it does not inherit.
    def effective_location
      return location.location if location

      parent = self.class.location_inheritance && public_send(self.class.location_inheritance)
      parent&.effective_location
    end

    def located_link
      "<a href='#{located_url}' class='text-decoration-none'><strong>#{ERB::Util.html_escape(to_s)}</strong></a>"
    end

    def located_map_style
      style = LocatableModels.map_style(self.class.base_class)
      { type: self.class.base_class.name, color: style[:color], icon: style[:icon] }
    end

    def located_url
      BetterTogether::Engine.routes.url_helpers.polymorphic_path(self, locale: I18n.locale)
    rescue NoMethodError
      Rails.application.routes.url_helpers.polymorphic_path(self, locale: I18n.locale)
    end

    def clear_location
      location&.mark_for_destruction
    end

    def settlement_identifier_must_exist
      errors.add(:settlement_identifier, :invalid) if @settlement_identifier_error
    end

    def address_data_must_be_valid
      errors.add(:address_data, @address_data_error) if @address_data_error
    end

    def locate_at_address(spec)
      attrs = parse_address_data(spec)
      return @address_data_error = 'must be an address with line1' if attrs['line1'].blank?

      name = attrs.delete('name') # CE's views show a location only when it has a name
      place = location || build_location
      place.assign_attributes(location: address_for(attrs), name: name.presence || place.name)
    end

    def parse_address_data(spec)
      spec = JSON.parse(spec) if spec.is_a?(String)
      spec.to_h.stringify_keys.slice(*ADDRESS_FIELDS).transform_values { |value| value.to_s.strip }.compact_blank
    end

    def address_for(attrs)
      BetterTogether::Address.find_by(attrs.slice(*ADDRESS_MATCH_FIELDS)) ||
        BetterTogether::Address.new(attrs.merge('physical' => true, 'postal' => false, 'privacy' => 'public'))
    end

    private :clear_location, :settlement_identifier_must_exist, :address_data_must_be_valid, :parse_address_data,
            :address_for, :locate_at_address, :located_url, :located_link, :located_map_style
  end
end
