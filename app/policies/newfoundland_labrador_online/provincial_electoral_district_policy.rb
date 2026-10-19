# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # Districts are public reference data; reads and edits follow the generic region rules.
  class ProvincialElectoralDistrictPolicy < BetterTogether::Geography::RegionPolicy
    class Scope < BetterTogether::Geography::RegionPolicy::Scope; end
  end
end
