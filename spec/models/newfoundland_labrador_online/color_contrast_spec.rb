# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable-next RSpec/ExampleLength
RSpec.describe NewfoundlandLabradorOnline::ColorContrast do
  it 'picks white on dark and near-black on light backgrounds' do
    expect([described_class.text_color_for('#0072B2'), described_class.text_color_for('#FFE08A')])
      .to eq(['#ffffff', '#111111'])
  end

  it 'reaches 4.5:1 for the shipped meeting colours' do
    YAML.load_file(Rails.root.join('config/meetings/sources.yml')).each_value do |source|
      source['bodies'].each_value do |body|
        ratio = described_class.contrast_ratio(body['color'], described_class.text_color_for(body['color']))
        expect(ratio).to be >= 4.5, "#{body['name']} #{body['color']} => #{ratio.round(2)}"
      end
    end
  end
end
