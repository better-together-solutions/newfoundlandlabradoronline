# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'better_together/robots/_mention', type: :view do
  let(:robot) do
    BetterTogether::Robot.new(id: SecureRandom.uuid, name: 'Corner Brook Online Publisher', identifier: 'cbo-publisher',
                              robot_type: 'automation', provider: 'ollama')
  end

  before { render partial: 'better_together/robots/mention', locals: { robot: } }

  it 'shows the robot name and kind' do
    expect(rendered).to include('Corner Brook Online Publisher', 'Robot')
  end

  it 'draws the avatar as a stacked circle that cannot be squashed', :aggregate_failures do
    expect(rendered).to include('fa-stack', 'fa-circle fa-stack-2x', 'fa-robot fa-stack-1x', 'flex-shrink-0')
    expect(rendered).not_to include('h-50')
  end

  it 'labels the avatar for assistive technology' do
    expect(rendered).to include('role="img"', 'aria-label="Robot author"')
  end
end
