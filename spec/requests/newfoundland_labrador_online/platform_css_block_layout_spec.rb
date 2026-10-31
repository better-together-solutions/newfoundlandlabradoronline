# frozen_string_literal: true

require 'rails_helper'

# CE's layouts render the platform CSS block as a record. Rails prefixes the controller namespace onto a
# record's partial path, so NLO controllers once looked for newfoundland_labrador_online/better_together/...
# and returned 500 whenever the layout fragment was not already cached by a CE controller.
RSpec.describe 'Platform CSS block in NLO controller layouts' do
  include RequestSpecHelper

  before do
    platform = configure_host_platform
    platform.update!(css_block_attributes: { content: 'body { color: #123456; }' })
  end

  %w[e/districts/provincial/nl e/parties e/elections].each do |path|
    it "renders /#{path} with a CSS block set", :aggregate_failures do
      get "/#{I18n.default_locale}/#{path}"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('color: #123456')
    end
  end
end
