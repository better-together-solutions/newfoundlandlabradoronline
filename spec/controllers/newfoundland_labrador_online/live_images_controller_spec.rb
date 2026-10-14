# frozen_string_literal: true

require 'rails_helper'

RSpec.describe NewfoundlandLabradorOnline::LiveImagesController, type: :request do
  let(:live_image) { NewfoundlandLabradorOnline::LiveImage }
  let(:frame) { live_image::Frame.new('jpegbytes', Time.zone.parse('2026-10-14 15:25:00'), 'abc123') }

  it 'serves the frame as a JPEG with its modified time', :aggregate_failures do
    allow(live_image).to receive(:frame).with('corner-brook').and_return(frame)

    get '/live/corner-brook.jpg'

    expect(response).to have_http_status(:ok)
    expect([response.media_type, response.body]).to eq(['image/jpeg', 'jpegbytes'])
    expect(response.headers['Last-Modified']).to be_present
  end

  it 'marks the frame as briefly cacheable by browsers and CDNs' do
    allow(live_image).to receive(:frame).and_return(frame)

    get '/live/corner-brook.jpg'

    expect(response.headers['Cache-Control']).to include('public', 'max-age=30', 's-maxage=60')
  end

  it 'answers a matching ETag with 304' do
    allow(live_image).to receive(:frame).and_return(frame)
    get '/live/corner-brook.jpg'

    get '/live/corner-brook.jpg', headers: { 'If-None-Match' => response.headers['ETag'] }

    expect(response).to have_http_status(:not_modified)
  end

  it 'asks the client to retry when no frame is available', :aggregate_failures do
    allow(live_image).to receive(:frame).and_return(nil)

    get '/live/corner-brook.jpg'

    expect(response).to have_http_status(:service_unavailable)
    expect(response.headers['Retry-After']).to eq('30')
  end

  it 'returns 404 for an unknown camera' do
    get '/live/nowhere.jpg'

    expect(response).to have_http_status(:not_found)
  end
end
