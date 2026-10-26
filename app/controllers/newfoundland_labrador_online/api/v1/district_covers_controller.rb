# frozen_string_literal: true

module NewfoundlandLabradorOnline
  module Api
    module V1
      # Lets the cover generator attach a generated map to a district over the API (base64 body, like post covers).
      # A cover someone uploaded by hand is never replaced. Needs a trusted OAuth app or a platform manager.
      class DistrictCoversController < BetterTogether::Api::ApplicationController
        before_action :require_trusted_oauth_application_or_platform_manager!
        skip_after_action :enforce_policy_use

        def update
          district = NewfoundlandLabradorOnline::ProvincialElectoralDistrict.find(params[:id])
          image = BetterTogether::ImageInput.decode(params[:cover_image_data].to_s)
          return render_invalid(image.error) if image.error

          result = attach(district, image)
          render json: { id: district.id, status: result.status }
        end

        private

        def attach(district, image)
          filename = BetterTogether::ImageInput.filename(params[:cover_image_filename], image.type, district.identifier)
          Geography::DistrictCover.call(region: district, io: StringIO.new(image.bytes), filename:)
        end

        def render_invalid(error)
          render json: { error: "cover_image_data #{error}" }, status: :unprocessable_content
        end
      end
    end
  end
end
