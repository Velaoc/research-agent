# frozen_string_literal: true

module Foundation
  # Outermost Rack defense so previews remain unindexable even for static
  # files, health endpoints, and rendered errors that bypass controllers.
  class NoindexMiddleware
    def initialize(app)
      @app = app
    end

    def call(env)
      status, headers, body = @app.call(env)
      if Foundation.runtime_config.preview?
        headers = headers.dup
        headers["X-Robots-Tag"] = "noindex"
      end
      [ status, headers, body ]
    end
  end
end
