# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # Maps URL province codes (nl, ns, ...) to the geography State rows, whose iso_code is the ISO 3166-2 form (CA-NL).
  module Province
    module_function

    def state_for(code)
      BetterTogether::Geography::State.find_by!(iso_code: "CA-#{code.to_s.upcase}")
    end

    # By province code (nl), else by the state's slug or id.
    def find_state(param)
      param.to_s.match?(/\A[a-z]{2}\z/) ? state_for(param) : BetterTogether::Geography::State.friendly.find(param)
    end

    def code_for(state)
      state.iso_code.delete_prefix('CA-').downcase
    end
  end
end
