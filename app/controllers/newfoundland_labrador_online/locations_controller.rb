# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # Lookup endpoint behind the shared location picker (views/newfoundland_labrador_online/locations/_picker).
  # It answers for any locatable form (posts, communities, ...) by dispatching to CE's
  # LocatableLocation.available_<type>_for scopes, which already apply each type's privacy rules.
  class LocationsController < BetterTogether::ApplicationController
    MIXED_RESULTS_PER_TYPE = 5

    before_action :authenticate_user!

    def available
      return render(json: mixed_options) if params[:location_type].blank?

      scope = requested_scope
      return render(json: { error: 'Invalid location type' }, status: :unprocessable_entity) unless scope

      render json: scope.map { |record| { value: record.id, text: label_for(record) } }
    end

    private

    def requested_scope
      klass = placeable_models.find { |model| model.name == params[:location_type] }
      klass && scope_for(klass)
    end

    def placeable_models
      BetterTogether::Geography::Placeable.included_in_models
    end

    def scope_for(klass)
      method_name = "available_#{klass.name.demodulize.underscore.pluralize}_for"
      locations = BetterTogether::Geography::LocatableLocation
      return unless locations.respond_to?(method_name)

      locations.public_send(method_name, current_user.person, search: params[:search])
    end

    def mixed_options
      placeable_models.flat_map do |klass|
        scope = scope_for(klass)
        next [] unless scope

        scope.limit(MIXED_RESULTS_PER_TYPE).map do |record|
          { value: "#{klass.name}:#{record.id}", text: "#{label_for(record)} (#{klass.model_name.human})" }
        end
      end
    end

    def label_for(record)
      record.respond_to?(:to_formatted_s) ? record.to_formatted_s : record.to_s
    end
  end
end
