# frozen_string_literal: true

require 'rails_helper'

RSpec.describe NewfoundlandLabradorOnline::LocatableResource do
  NewfoundlandLabradorOnline::LocatableModels.models.each do |model|
    describe "the #{model.name} API resource" do
      let(:resource) { NewfoundlandLabradorOnline::LocatableModels.resource_for(model) }

      it 'reads and writes settlement_identifier', :aggregate_failures do
        expect(resource.creatable_fields({})).to include(:settlement_identifier)
        expect(resource.updatable_fields({})).to include(:settlement_identifier)
        expect(resource.new(model.new, {}).fetchable_fields).to include(:settlement_identifier)
      end
    end
  end
end
