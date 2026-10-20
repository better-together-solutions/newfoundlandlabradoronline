# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # The provincial data attached to a BetterTogether::Geography::State (province).
  module State
    extend ActiveSupport::Concern

    included do
      has_many :provincial_electoral_districts, class_name: 'NewfoundlandLabradorOnline::ProvincialElectoralDistrict',
                                                foreign_key: :state_id, inverse_of: :state,
                                                dependent: :restrict_with_error
      has_many :political_parties, class_name: 'NewfoundlandLabradorOnline::PoliticalParty', foreign_key: :state_id,
                                   inverse_of: :state, dependent: :restrict_with_error
      has_many :elections, class_name: 'NewfoundlandLabradorOnline::Election', foreign_key: :state_id,
                           inverse_of: :state, dependent: :restrict_with_error
    end
  end
end
