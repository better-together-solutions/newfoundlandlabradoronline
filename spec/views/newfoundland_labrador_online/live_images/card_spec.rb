# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'newfoundland_labrador_online/live_images/_card' do
  include ActiveSupport::Testing::TimeHelpers

  around { |example| travel_to(Time.zone.parse('2026-10-14 12:00:30')) { example.run } }

  before do
    render partial: 'newfoundland_labrador_online/live_images/card',
           locals: { slug: 'corner-brook', title: 'Corner Brook Online' }
  end

  it 'shows the same-origin image with a heading and alt text', :aggregate_failures do
    expect(rendered).to match(%r{src="/live/corner-brook\.jpg\?t=\d+"})
    expect(rendered).to include('Corner Brook Online right now')
    expect(rendered).to include('alt="Latest camera image over Corner Brook Online"')
  end

  it 'puts the current minute in the image URL so a browser or CDN copy is at most a minute old' do
    expect(rendered).to include("?t=#{Time.zone.parse('2026-10-14 12:00:00').to_i / 60}\"")
  end

  it 'leaves the time empty until a frame has been fetched' do
    expect(rendered).to include('<time data-live-image-target="time"></time>')
  end

  it 'shows when the camera took the cached frame' do
    taken = Time.find_zone('America/St_Johns').local(2026, 10, 14, 18, 44, 45)
    allow(NewfoundlandLabradorOnline::LiveImage).to receive(:peek)
      .and_return(NewfoundlandLabradorOnline::LiveImage::Frame.new('x', Time.current, 'e', taken))
    render partial: 'newfoundland_labrador_online/live_images/card', locals: { slug: 'corner-brook', title: 'CB' }

    expect(rendered).to include("datetime=\"#{taken.iso8601}\"", '6:44 PM NDT')
  end

  it 'wires the refresh controller' do
    expect(rendered).to include('data-controller="live-image"', 'data-live-image-target="image"',
                                'data-live-image-target="time"')
  end
end
