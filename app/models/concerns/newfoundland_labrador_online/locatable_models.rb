# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # The one list of records that take part in the location system. config/initializers wires each entry
  # (the model concern, the API attribute) and the shared examples in spec/support check each one.
  #
  # To onboard a model: add it to ONBOARDED, add the `inherit` option if it should fall back to a
  # parent's location, run the specs, add the picker to its form (docs/locatable-onboarding.md).
  module LocatableModels
    # concern: :locatable adds the has_one, nested attributes and the interface;
    # :interface adds only the interface, for models that already have CE's Locatable::One (events).
    ONBOARDED = {
      'BetterTogether::Post' => { concern: :locatable, inherit: :community },
      'BetterTogether::Community' => { concern: :locatable },
      'BetterTogether::Event' => { concern: :interface }
    }.freeze

    # Wanted but not onboarded yet (noted only, nothing wired).
    PENDING = %w[BetterTogether::Joatu::Offer BetterTogether::Joatu::Request].freeze

    module_function

    def models
      ONBOARDED.keys.map(&:constantize)
    end

    def wire!
      ONBOARDED.each do |name, options|
        model = name.constantize
        model.include(options[:concern] == :locatable ? Locatable : LocationInterface)
        model.inherit_location_from(options[:inherit]) if options[:inherit]
      end
    end

    def resource_for(model)
      "BetterTogether::Api::V1::#{model.name.demodulize}Resource".constantize
    end
  end
end
