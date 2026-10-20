# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # PoliticalParty records are public reference data.
  class PoliticalPartyPolicy < BetterTogether::ApplicationPolicy
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
