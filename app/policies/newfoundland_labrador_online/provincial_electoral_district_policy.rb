# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # Districts are public reference data: anyone may read them. Edits follow the generic region rules.
  class ProvincialElectoralDistrictPolicy < BetterTogether::Geography::RegionPolicy
    def index?
      true
    end

    def show?
      true
    end

    class Scope < BetterTogether::Geography::RegionPolicy::Scope; end
  end
end
