# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # Resolves the :province URL segment to its geography State; an unknown code is a 404.
  module ProvinceScoped
    extend ActiveSupport::Concern

    # What a page that shows members (avatar, name, party) needs from each Person.
    PERSON_PRELOAD = [:string_translations, :slugs, { profile_image_attachment: :blob }].freeze

    included do
      before_action :set_province
      helper NewfoundlandLabradorOnline::ProvincesHelper
    end

    private

    def set_province
      @province = NewfoundlandLabradorOnline::Province.state_for(params[:province]) if params[:province]
    end
  end
end
