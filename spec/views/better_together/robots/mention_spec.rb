# frozen_string_literal: true

require 'rails_helper'

# A stale host copy of this partial once squashed the avatar into an oval. The CE
# partial is used as-is; this guards the circle and the gap if a copy comes back.
RSpec.describe 'better_together/robots/_mention' do
  let(:robot) { create(:better_together_robot, name: 'BTS Robot') }

  before { render partial: 'better_together/robots/mention', locals: { robot: } }

  it 'renders an equal-sided circle that cannot be squeezed, with a gap before the name', :aggregate_failures do
    avatar = Capybara.string(rendered).find('.robot-avatar')

    expect(avatar[:class].split).to include('rounded-circle', 'flex-shrink-0', 'me-2')
    width, height = avatar[:style].scan(/(?:width|height):\s*(\d+px)/).flatten
    expect(width).to eq(height)
  end
end
