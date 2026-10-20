# frozen_string_literal: true

module NewfoundlandLabradorOnline
  module Geography
    # Adds (or updates) the public "Districts" link to the platform header. Idempotent; the header area must exist.
    class DistrictsNavigationItem
      TITLES = { en: 'Districts', es: 'Distritos electorales', fr: 'Circonscriptions' }.freeze

      def call
        area = BetterTogether::NavigationArea.find_by!(identifier: 'platform-header')
        item = area.navigation_items.find_or_initialize_by(identifier: 'districts')
        item.assign_attributes(attributes_for(area, item))
        item.save!
        item
      end

      private

      def attributes_for(area, item)
        position = item.position || (area.navigation_items.maximum(:position).to_i + 1)
        titles = TITLES.transform_keys { |locale| :"title_#{locale}" }
        { slug_en: 'districts', item_type: 'link', url: '/e/districts/provincial/nl', visible: true, privacy: 'public',
          visibility_strategy: 'authenticated', position:, navigation_area: area }.merge(titles)
      end
    end
  end
end
