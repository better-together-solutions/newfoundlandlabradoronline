# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # Election records are public reference data.
  class ElectionPolicy < BetterTogether::ApplicationPolicy
    def index?
      true
    end

    def show?
      true
    end

    # Everything is visible.
    class Scope < BetterTogether::ApplicationPolicy::Scope
      def resolve
        scope.all
      end
    end
  end
end
