# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # Civic behaviour of a person (members of the House of Assembly): their primary community stays private.
  module Person
    extend ActiveSupport::Concern

    included do
      include BetterTogether::PrivatePrimaryCommunity
    end
  end
end
