# frozen_string_literal: true

require 'rails_helper'

RSpec.describe NewfoundlandLabradorOnline::Geography::DistrictsNavigationItem do
  include RequestSpecHelper

  before do
    configure_host_platform
    unless BetterTogether::NavigationArea.exists?(identifier: 'platform-header')
      create(:navigation_area,
             identifier: 'platform-header')
    end
  end

  it 'adds one public header link with translated titles and is idempotent', :aggregate_failures do
    described_class.new.call
    item = described_class.new.call

    expect(BetterTogether::NavigationItem.where(identifier: 'districts').count).to eq(1)
    expect(item).to have_attributes(url: '/g/districts/provincial', privacy: 'public', title_fr: 'Circonscriptions')
  end
end
