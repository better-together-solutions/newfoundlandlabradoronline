# frozen_string_literal: true

module RequestSpecHelper
  include Rails.application.routes.url_helpers
  include BetterTogether::Engine.routes.url_helpers

  # Ensure route helpers use default locale
  def default_url_options
    { locale: I18n.default_locale }
  end

  def json
    JSON.parse(response.body)
  end

  def login(email, password)
    post better_together.user_session_path(locale: I18n.locale || I18n.default_locale), params: {
      user: { email: email, password: password }
    }
  end

  def configure_host_platform
    host_platform = BetterTogether::Platform.find_by(host: true) ||
                    create(:better_together_platform, :host, privacy: 'public')
    force_platform_and_community_public(host_platform)
    wizard = BetterTogether::Wizard.find_or_create_by(identifier: 'host_setup')
    wizard.mark_completed
    create(:user, :confirmed, :platform_manager,
           email: 'manager@example.test',
           password: 'SecureTest123!@#')
    host_platform
  end

  # See rails_helper.rb's before(:suite) hook for why this uses
  # update_columns: platform and its own primary community's privacy
  # ceilings are circular (each derived from the other), and autosave
  # cascades one into the other's transaction, so neither can be
  # validated-and-saved first in isolation.
  def force_platform_and_community_public(platform)
    platform.update_columns(privacy: 'public') unless platform.privacy == 'public'
    community = platform.primary_community
    community&.update_columns(privacy: 'public') if community && community.privacy != 'public'
  end
end
