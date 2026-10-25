# frozen_string_literal: true

require 'rails_helper'

RSpec.describe NewfoundlandLabradorOnline::EventResourceExtension do
  let(:resource) { BetterTogether::Api::V1::EventResource }

  it 'accepts the host and cover image fields on create and update', :aggregate_failures do
    %i[hosts status cover_image_data cover_image_filename attachment_block_ids].each do |field|
      expect(resource.creatable_fields({})).to include(field)
      expect(resource.updatable_fields({})).to include(field)
    end
  end

  it 'never returns the write-only image fields' do
    fields = resource.new(BetterTogether::Event.new, {}).fetchable_fields

    expect(fields).not_to include(:cover_image_data, :cover_image_filename, :attachment_block_ids)
  end

  describe 'naming hosts' do
    let(:community) { create(:better_together_community) }
    let(:person) { create(:better_together_person) }
    let(:user) { instance_double(BetterTogether::User, person:) }
    let(:specs) { [{ host_type: community.class.name, host_id: community.id }] }

    def assign(value)
      instance = resource.new(BetterTogether::Event.new, { current_user: user })
      instance.hosts = value
      instance
    end

    it 'allows hosts the person can host for, as a list or JSON', :aggregate_failures do
      allow(person).to receive_messages(valid_event_host_ids: [community.id, person.id], permitted_to?: false)

      expect(assign(specs)._model.hosts).to eq(specs)
      expect(assign(specs.to_json)._model.hosts).to eq(specs)
    end

    it 'allows a platform manager to name any host' do
      allow(person).to receive_messages(valid_event_host_ids: [], permitted_to?: true)

      expect(assign(specs)._model.hosts).to eq(specs)
    end

    it 'refuses a host the person cannot host for' do
      allow(person).to receive_messages(valid_event_host_ids: [], permitted_to?: false)

      expect { assign(specs) }.to raise_error(JSONAPI::Exceptions::InvalidFieldValue)
    end
  end

  describe 'status' do
    def assign(value)
      instance = resource.new(BetterTogether::Event.new, {})
      instance.status = value
      instance
    end

    it 'sets a known lifecycle status' do
      expect(assign('confirmed')._model).to be_status_confirmed
    end

    it 'refuses an unknown status' do
      expect { assign('published') }.to raise_error(JSONAPI::Exceptions::InvalidFieldValue)
    end
  end
end
