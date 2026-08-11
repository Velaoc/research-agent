module Foundation
  # Serves the versioned legal documents at /legal/terms and /legal/privacy
  # (SPEC M2.4). Public, no authentication.
  class LegalController < ApplicationController
    def terms
      set_meta_tags title: "Terms of Service"
    end

    def privacy
      set_meta_tags title: "Privacy Policy"
    end
  end
end
