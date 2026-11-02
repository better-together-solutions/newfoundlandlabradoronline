# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # Municipal councils and their elections are public record, shown through the settlement they govern.
  class MunicipalityPolicy < BetterTogether::ApplicationPolicy
    def index?
      true
    end

    def show?
      true
    end

    # Every municipality is public.
    class Scope < BetterTogether::ApplicationPolicy::Scope
      def resolve
        scope.all
      end
    end
  end
end
