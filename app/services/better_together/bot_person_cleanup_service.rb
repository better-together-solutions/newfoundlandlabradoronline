# frozen_string_literal: true

module BetterTogether
  # Guarded cleanup for explicit bot person IDs on NLO. Dry-run is the default;
  # write mode validates each target, clears the community creator/protected
  # cycle, then destroys the person through the model layer.
  class BotPersonCleanupService # rubocop:disable Metrics/ClassLength
    BOOLEAN = ActiveModel::Type::Boolean.new
    BOT_EMAIL_ERROR = 'contact email addresses present; cleanup may enqueue removal mail'

    class CleanupError < StandardError; end

    attr_reader :person_ids, :preserve_person_ids, :write_enable

    def initialize(person_ids:, preserve_person_ids: [], write_enable: false, logger: Rails.logger)
      @person_ids = normalize_ids(person_ids)
      @preserve_person_ids = normalize_ids(preserve_person_ids)
      @write_enable = BOOLEAN.cast(write_enable)
      @logger = logger
    end

    # rubocop:disable Metrics/AbcSize
    def call
      raise CleanupError, 'No target person IDs were provided.' if person_ids.empty?

      people = load_people
      missing_ids = person_ids - people.keys
      raise CleanupError, "Missing target people: #{missing_ids.join(', ')}" if missing_ids.any?

      {
        write_enable:,
        target_person_ids: person_ids,
        preserve_person_ids:,
        results: person_ids.map { |person_id| inspect_or_cleanup(people.fetch(person_id)) }
      }
    end
    # rubocop:enable Metrics/AbcSize

    private

    attr_reader :logger

    def normalize_ids(ids)
      Array(ids).map(&:to_s).map(&:strip).reject(&:empty?).uniq
    end

    def load_people
      BetterTogether::Person.includes(:user, :community).where(id: person_ids).index_by(&:id)
    end

    # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    def inspect_or_cleanup(person)
      snapshot = snapshot_for(person)
      preflight_errors = preflight_errors_for(person, snapshot)

      result = {
        person_id: person.id,
        identifier: person.identifier,
        community_id: person.community_id,
        user_id: person.user&.id,
        snapshot:,
        preflight_errors:,
        deleted: false
      }

      log_result(result)
      return result unless write_enable

      raise CleanupError, "Preflight failed for #{person.id}: #{preflight_errors.join('; ')}" if preflight_errors.any?

      prepare_community_for_destroy(person.community)
      person.destroy!
      result[:deleted] = true
      result[:verification] = verification_for(person_id: person.id, community_id: snapshot[:community_id])
      log_verification(result)
      result
    end
    # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

    # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    def snapshot_for(person)
      community_id = person.community_id

      {
        community_id:,
        community_protected: person.community&.protected?,
        contact_detail_count: BetterTogether::ContactDetail.where(contactable: person).count,
        email_address_count: person.email_addresses.count,
        phone_number_count: person.phone_numbers.count,
        address_count: person.addresses.count,
        social_media_account_count: person.social_media_accounts.count,
        website_link_count: person.website_links.count,
        agreement_participant_count: BetterTogether::AgreementParticipant.where(person_id: person.id).count,
        person_calendar_count: BetterTogether::Calendar.where(creator_id: person.id).count,
        community_calendar_count: BetterTogether::Calendar.where(community_id: community_id).count,
        person_community_membership_count: BetterTogether::PersonCommunityMembership.where(member_id: person.id).count,
        person_platform_membership_count: BetterTogether::PersonPlatformMembership.where(member_id: person.id).count,
        page_count: BetterTogether::Page.where(community_id: community_id).count,
        place_count: BetterTogether::Place.where(community_id: community_id).count,
        platform_count: BetterTogether::Platform.where(community_id: community_id).count,
        webhook_endpoint_count: BetterTogether::WebhookEndpoint.where(community_id: community_id).count
      }
    end
    # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

    # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
    def preflight_errors_for(person, snapshot)
      errors = []
      community_id = snapshot[:community_id]
      allowed_ids = person_ids + preserve_person_ids

      errors << 'preserved person id' if preserve_person_ids.include?(person.id)
      errors << 'rob identifier' if person.identifier == 'rob'
      errors << 'linked user present' if person.user.present?
      errors << 'primary community missing' if community_id.blank?
      errors << 'community not found' if community_id.present? && person.community.blank?
      errors << 'community creator mismatch' if person.community.present? && person.community.creator_id != person.id

      errors << BOT_EMAIL_ERROR if snapshot[:email_address_count].positive?

      if community_id.present?
        errors << 'community has non-target members' if non_target_members?(community_id, allowed_ids)
        errors << 'community has non-target authored pages' if non_target_pages?(community_id, allowed_ids)
        errors << 'community has non-target authored calendars' if non_target_calendars?(community_id, allowed_ids)
      end

      errors
    end
    # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity

    def non_target_members?(community_id, allowed_ids)
      BetterTogether::PersonCommunityMembership.where(joinable_id: community_id)
                                               .where.not(member_id: allowed_ids)
                                               .exists?
    end

    def non_target_pages?(community_id, allowed_ids)
      BetterTogether::Page.where(community_id:)
                          .where.not(creator_id: allowed_ids + [nil])
                          .exists?
    end

    def non_target_calendars?(community_id, allowed_ids)
      BetterTogether::Calendar.where(community_id:)
                              .where.not(creator_id: allowed_ids + [nil])
                              .exists?
    end

    def prepare_community_for_destroy(community)
      return if community.blank?

      updates = {}
      updates[:creator_id] = nil if community.creator_id.present?
      updates[:protected] = false if community.protected?
      community.update!(updates) if updates.any?
    end

    # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    def verification_for(person_id:, community_id:)
      {
        person_exists: BetterTogether::Person.exists?(id: person_id),
        community_exists: BetterTogether::Community.exists?(id: community_id),
        remaining_contact_details: remaining_contact_details(person_id),
        remaining_email_addresses: remaining_email_addresses(person_id),
        remaining_agreement_participants: BetterTogether::AgreementParticipant.where(person_id:).count,
        remaining_person_calendars: BetterTogether::Calendar.where(creator_id: person_id).count,
        remaining_community_calendars: BetterTogether::Calendar.where(community_id:).count,
        remaining_person_community_memberships: membership_count(
          BetterTogether::PersonCommunityMembership,
          person_id
        ),
        remaining_person_platform_memberships: membership_count(
          BetterTogether::PersonPlatformMembership,
          person_id
        ),
        remaining_pages_for_community: BetterTogether::Page.where(community_id:).count,
        remaining_places_for_community: BetterTogether::Place.where(community_id:).count,
        remaining_platforms_for_community: BetterTogether::Platform.where(community_id:).count,
        remaining_webhook_endpoints_for_community: BetterTogether::WebhookEndpoint.where(community_id:).count
      }
    end
    # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

    def remaining_contact_details(person_id)
      BetterTogether::ContactDetail.where(
        contactable_type: 'BetterTogether::Person',
        contactable_id: person_id
      ).count
    end

    def remaining_email_addresses(person_id)
      BetterTogether::EmailAddress.joins(:contact_detail)
                                  .where(
                                    better_together_contact_details: {
                                      contactable_type: 'BetterTogether::Person',
                                      contactable_id: person_id
                                    }
                                  )
                                  .count
    end

    def membership_count(model_class, person_id)
      model_class.where(member_id: person_id).count
    end

    def log_result(result)
      logger.info(
        "[bot-person-cleanup] inspected person_id=#{result[:person_id]} " \
        "identifier=#{result[:identifier]} deleted=#{result[:deleted]} " \
        "preflight_errors=#{result[:preflight_errors].join('|')}"
      )
    end

    def log_verification(result)
      logger.info(
        "[bot-person-cleanup] verification person_id=#{result[:person_id]} " \
        "person_exists=#{result.dig(:verification, :person_exists)} " \
        "community_exists=#{result.dig(:verification, :community_exists)}"
      )
    end
  end
end
