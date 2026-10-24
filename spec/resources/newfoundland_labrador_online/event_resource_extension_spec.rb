# frozen_string_literal: true

require 'rails_helper'

RSpec.describe NewfoundlandLabradorOnline::EventResourceExtension do
  let(:resource) { BetterTogether::Api::V1::EventResource }

  it 'accepts the host and cover image fields on create and update', :aggregate_failures do
    %i[host_community_id cover_image_data cover_image_filename].each do |field|
      expect(resource.creatable_fields({})).to include(field)
      expect(resource.updatable_fields({})).to include(field)
    end
  end

  it 'never returns the write-only image fields' do
    fields = resource.new(BetterTogether::Event.new, {}).fetchable_fields

    expect(fields).not_to include(:cover_image_data, :cover_image_filename)
  end

  describe 'naming a host community' do
    let(:community) { create(:better_together_community) }
    let(:person) { create(:better_together_person) }
    let(:user) { instance_double(BetterTogether::User, person:) }

    def assign(id)
      instance = resource.new(BetterTogether::Event.new, { current_user: user })
      instance.host_community_id = id
      instance
    end

    it 'allows a community the person can host for' do
      allow(person).to receive_messages(valid_event_host_ids: [community.id], permitted_to?: false)

      expect(assign(community.id)._model.host_community_id).to eq(community.id)
    end

    it 'allows a platform manager to name any community' do
      allow(person).to receive_messages(valid_event_host_ids: [], permitted_to?: true)

      expect(assign(community.id)._model.host_community_id).to eq(community.id)
    end

    it 'refuses a community the person cannot host for' do
      allow(person).to receive_messages(valid_event_host_ids: [], permitted_to?: false)

      expect { assign(community.id) }.to raise_error(JSONAPI::Exceptions::InvalidFieldValue)
    end
  end
end
