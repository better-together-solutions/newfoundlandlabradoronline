# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::BotPersonCleanupService do
  let(:logger) { Logger.new(nil) }
  let(:service_result) do
    described_class.new(
      person_ids: [person.id],
      preserve_person_ids: preserve_person_ids,
      write_enable:,
      logger:
    ).call[:results].first
  end
  let(:preserve_person_ids) { [] }
  let(:write_enable) { false }

  describe '#call' do
    # rubocop:disable RSpec/ExampleLength, RSpec/MultipleExpectations
    it 'reports a dry run without deleting the target person' do
      person = BetterTogether::Person.create!(name: 'Bot Cleanup Target', identifier: 'bot-cleanup-target')
      person.community.update!(creator_id: person.id)
      result = described_class.new(person_ids: [person.id], logger:).call

      expect(result).to include(write_enable: false, target_person_ids: [person.id], preserve_person_ids: [])
      expect(result[:results].first).to include(person_id: person.id, deleted: false, preflight_errors: [])
      expect(BetterTogether::Person.exists?(id: person.id)).to be(true)
      expect(BetterTogether::Community.exists?(id: person.community_id)).to be(true)
    end
    # rubocop:enable RSpec/ExampleLength, RSpec/MultipleExpectations

    it 'fails preflight when the target person has contact email addresses' do
      person = BetterTogether::Person.create!(name: 'Bot With Email', identifier: 'bot-with-email')
      person.community.update!(creator_id: person.id)
      person.contact_detail.email_addresses.create!(email: 'bot@example.test', label: 'other', primary_flag: true)

      result = described_class.new(person_ids: [person.id], logger:).call

      expect(result[:results].first[:preflight_errors]).to include(described_class::BOT_EMAIL_ERROR)
    end

    # rubocop:disable RSpec/ExampleLength
    it 'fails preflight when the target community has non-target members' do
      community_role = BetterTogether::Role.where(resource_type: 'BetterTogether::Community').first!
      target_person = BetterTogether::Person.create!(name: 'Bot Community Owner', identifier: 'bot-community-owner')
      target_person.community.update!(creator_id: target_person.id)
      outsider = BetterTogether::Person.create!(name: 'Real Member', identifier: 'real-member')

      BetterTogether::PersonCommunityMembership.create!(
        member: outsider,
        joinable: target_person.community,
        role: community_role,
        status: :active
      )

      result = described_class.new(person_ids: [target_person.id], logger:).call

      expect(result[:results].first[:preflight_errors]).to include('community has non-target members')
    end
    # rubocop:enable RSpec/ExampleLength

    # rubocop:disable RSpec/ExampleLength, RSpec/MultipleExpectations
    it 'destroys the target person and primary community when write is enabled' do
      person = BetterTogether::Person.create!(name: 'Disposable Bot', identifier: 'disposable-bot')
      person.community.update!(creator_id: person.id)
      community_id = person.community_id
      result = described_class.new(person_ids: [person.id], write_enable: true, logger:).call

      verification = result[:results].first[:verification]
      expect(result[:results].first[:deleted]).to be(true)
      expect(verification[:person_exists]).to be(false)
      expect(verification[:community_exists]).to be(false)
      expect(verification[:remaining_community_calendars]).to eq(0)
      expect(BetterTogether::Person.exists?(id: person.id)).to be(false)
      expect(BetterTogether::Community.exists?(id: community_id)).to be(false)
    end
    # rubocop:enable RSpec/ExampleLength, RSpec/MultipleExpectations
  end
end
