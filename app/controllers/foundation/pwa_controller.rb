module Foundation
  # Serves the web application manifest (SPEC M10.2). Public, no
  # authentication, and no product identity of its own: every value comes
  # from config/foundation.yml through Foundation::WebManifest, so stamping
  # an identity with bin/rename is enough to rebrand the installed app.
  class PwaController < ApplicationController
    def manifest
      expires_in 1.hour, public: true

      render json: WebManifest.new(Rails.configuration.x.foundation).as_json,
        content_type: "application/manifest+json"
    end
  end
end
