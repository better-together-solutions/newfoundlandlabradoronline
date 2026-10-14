# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # Local-only fixtures for exercising the Corner Brook Online publisher end to end: the host
  # platform, a platform steward standing in for the director, the public community, the
  # publisher robot, the video categories and an OAuth application owned by the steward.
  # Idempotent except the OAuth application, which is recreated for a fresh secret.
  class DevPublishingFixtures
    STEWARD_EMAIL = 'cbo-dev-steward@example.test'
    STEWARD_IDENTIFIER = 'cbo-dev-steward'
    COMMUNITY_IDENTIFIER = 'corner-brook-online'
    ROBOT_IDENTIFIER = 'cbo-publisher'
    APP_NAME = 'cbo-publisher-dev'
    SCOPES = 'read write write_posts'
    AGREEMENT = 'content_publishing_agreement'

    def initialize(base_url:)
      @base_url = base_url
    end

    def provision!
      raise 'DevPublishingFixtures must not run in production' if Rails.env.production?

      platform = host_platform
      install_platform_defaults
      person = steward(platform)
      accept_publishing_agreement(person)
      records = { platform:, person:, community: corner_brook_online(person), robot: publisher_robot(platform) }
      NewfoundlandLabradorOnline::VideoCategoryBuilder.build
      result(records, oauth_application(platform, person))
    end

    # Removes what a previous publisher run created (yt- posts and their blocks) so a run starts clean.
    def reset_published!
      raise 'DevPublishingFixtures must not run in production' if Rails.env.production?

      ::BetterTogether::Post.where('identifier LIKE ?', 'yt-%').find_each(&:destroy!)
      ::BetterTogether::Content::VideoBlock.where('identifier LIKE ?', 'yt-%').find_each(&:destroy!)
    end

    private

    def install_platform_defaults
      ::BetterTogether::AccessControlBuilder.build
      complete_host_setup
      ::BetterTogether::NavigationBuilder.build unless ::BetterTogether::NavigationArea.exists?
    end

    def result(records, credentials)
      { base_url: @base_url, platform_id: records[:platform].id, community_id: records[:community].id,
        robot_id: records[:robot].id, editor_person_id: records[:person].id, client_id: credentials[:uid],
        client_secret: credentials[:secret], steward_email: STEWARD_EMAIL }
    end

    # Pages redirect to the setup wizard until the host wizard is marked complete.
    def complete_host_setup
      ::BetterTogether::SetupWizardBuilder.build unless ::BetterTogether::Wizard.exists?(identifier: 'host_setup')
      ::BetterTogether::Wizard.find_by(identifier: 'host_setup')&.mark_completed
    end

    def host_platform
      ::BetterTogether::Platform.find_by(host: true) || create_host_platform
    end

    def create_host_platform
      community = ::BetterTogether::Community.create!(name: 'Newfoundland Labrador Online (dev)', host: true,
                                                      identifier: 'nlo-dev-host', privacy: 'public', protected: true)
      ::BetterTogether::Platform.create!(
        name: community.name, identifier: 'nlo-dev', host: true, host_url: @base_url, community:, privacy: 'public',
        protected: true, time_zone: 'America/St_Johns', requires_invitation: false, allow_membership_requests: false
      )
    end

    def steward(platform)
      user = ::BetterTogether::User.find_or_initialize_by(email: STEWARD_EMAIL)
      if user.new_record?
        user.assign_attributes(password: SecureRandom.base58(24), confirmed_at: Time.zone.now)
        user.build_person(name: 'Dev Steward', identifier: STEWARD_IDENTIFIER)
        user.save!
      end
      grant_steward_role(platform, user.person)
      user.person
    end

    # CE refuses public content from an actor who has not accepted this agreement.
    def accept_publishing_agreement(person)
      ::BetterTogether::AgreementBuilder.build unless ::BetterTogether::Agreement.exists?(identifier: AGREEMENT)
      agreement = ::BetterTogether::Agreement.find_by!(identifier: AGREEMENT)
      return if agreement.accepted_by?(person)

      agreement.agreement_participants.create!(participant: person, accepted_at: Time.zone.now,
                                               acceptance_method: 'system')
    end

    def grant_steward_role(platform, person)
      role = ::BetterTogether::Role.find_by!(identifier: 'platform_steward')
      platform.person_platform_memberships.find_or_create_by!(member_id: person.id, role_id: role.id) do |membership|
        membership.status = 'active'
      end
    end

    def corner_brook_online(person)
      ::BetterTogether::Community.find_or_create_by!(identifier: COMMUNITY_IDENTIFIER) do |community|
        community.name = 'Corner Brook Online'
        community.description = 'Corner Brook community media'
        community.privacy = 'public'
        community.creator = person
      end
    end

    def publisher_robot(platform)
      ::BetterTogether::Robot.find_or_create_by!(identifier: ROBOT_IDENTIFIER, platform:) do |robot|
        robot.name = 'Corner Brook Online Publisher'
        robot.robot_type = 'automation'
        robot.provider = 'ollama'
      end
    end

    def oauth_application(platform, person)
      ::BetterTogether::OauthApplication.where(name: APP_NAME, owner: person).destroy_all
      app = ::BetterTogether::OauthApplication.create!(name: APP_NAME, owner: person, platform:, scopes: SCOPES,
                                                       confidential: true, redirect_uri: 'urn:ietf:wg:oauth:2.0:oob')
      { uid: app.uid, secret: app.plaintext_secret || app.secret }
    end
  end
end
