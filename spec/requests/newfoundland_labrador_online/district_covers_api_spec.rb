# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'District cover API', type: :request do
  include RequestSpecHelper

  let(:district) { NewfoundlandLabradorOnline::ProvincialElectoralDistrict.find_by!(identifier: 'nl-ped-corner-brook') }
  let(:path) { "/api/v1/geography_regions/#{district.id}/generated_cover" }
  let(:body) { { cover_image_data: Base64.strict_encode64(Vips::Image.black(40, 24).write_to_buffer('.jpg')) } }

  before do
    configure_host_platform
    NewfoundlandLabradorOnline::Geography::ProvincialDistrictLoader.new(
      path: Rails.root.join('spec/fixtures/nl_regions/two_districts.geojson')
    ).call
  end

  def put_cover(headers, params = body)
    put path, params: params.to_json, headers: headers.merge('Content-Type' => 'application/json')
  end

  context 'with a platform manager' do
    let(:headers) do
      api_auth_headers(BetterTogether::User.find_by!(email: 'manager@example.test'))
    end

    it 'attaches the generated cover and keeps it as the default', :aggregate_failures do
      put_cover(headers)

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['status']).to eq('attached')
      expect(district.reload).to be_generated_cover
      expect(district.default_cover_image).to be_attached
    end

    it 'rejects data that is not an image' do
      put_cover(headers, cover_image_data: Base64.strict_encode64('nope'))

      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'never replaces a cover uploaded by hand', :aggregate_failures do
      district.cover_image.attach(io: StringIO.new(Vips::Image.black(8, 8).write_to_buffer('.jpg')),
                                  filename: 'custom.jpg', content_type: 'image/jpeg')
      put_cover(headers)

      expect(JSON.parse(response.body)['status']).to eq('kept_custom')
      expect(district.reload.cover_image.filename.to_s).to eq('custom.jpg')
    end
  end

  it 'refuses a signed-in person who is not a manager' do
    user = create(:user, :confirmed, password: 'SecureTest123!@#')
    put_cover(api_auth_headers(user))

    expect(response).to have_http_status(:forbidden)
  end

  it 'refuses anonymous requests' do
    put_cover({ 'Accept' => 'application/json' })

    expect(response).to have_http_status(:unauthorized)
  end
end
