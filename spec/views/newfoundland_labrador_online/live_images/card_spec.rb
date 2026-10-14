# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'newfoundland_labrador_online/live_images/_card' do
  before do
    render partial: 'newfoundland_labrador_online/live_images/card',
           locals: { slug: 'corner-brook', title: 'Corner Brook Online' }
  end

  it 'shows the same-origin image with a heading and alt text', :aggregate_failures do
    expect(rendered).to include('src="/live/corner-brook.jpg"', 'Corner Brook Online right now')
    expect(rendered).to include('alt="Latest camera image over Corner Brook Online"')
  end

  it 'wires the refresh controller' do
    expect(rendered).to include('data-controller="live-image"', 'data-live-image-target="image"',
                                'data-live-image-target="time"')
  end
end
