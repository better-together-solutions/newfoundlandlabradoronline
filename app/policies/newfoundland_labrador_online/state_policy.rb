# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # Provinces are public like settlements: anyone can list and view them, managing them needs manage_platform.
  # Prepended onto BetterTogether::Geography::StatePolicy (config/initializers/better_together_models.rb).
  module StatePolicy
    def index?
      true
    end

    def show?
      true
    end

    def update?
      user.present? && permitted_to?('manage_platform')
    end

    def destroy?
      user.present? && !record.protected? && permitted_to?('manage_platform')
    end
  end
end
