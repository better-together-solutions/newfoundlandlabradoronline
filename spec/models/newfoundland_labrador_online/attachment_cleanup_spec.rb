# frozen_string_literal: true

require 'rails_helper'

# Every NLO model that declares a has_one attachment must use CE's cleanup concern, so removal flags and purge
# methods exist for each attachment.
RSpec.describe 'NLO attachment cleanup' do # rubocop:disable RSpec/DescribeClass
  before { Rails.application.eager_load! }

  let(:models) do
    ActiveRecord::Base.descendants.select { |model| model.name.to_s.start_with?('NewfoundlandLabradorOnline::') }
  end
  let(:attachments) do
    models.flat_map do |model|
      model.reflect_on_all_attachments.select { |reflection| reflection.macro == :has_one_attached }
           .map { |reflection| [model, reflection.name] }
    end
  end

  it 'finds the attachments to check' do
    expect(attachments).to include([NewfoundlandLabradorOnline::PoliticalParty, :logo])
  end

  it 'has a removal flag and purge method for every attachment', :aggregate_failures do
    attachments.each do |model, name|
      expect(model.new).to respond_to(:"remove_#{name}", :"purge_#{name}"), "#{model} #{name} lacks cleanup"
    end
  end
end
