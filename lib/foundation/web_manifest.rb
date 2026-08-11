# frozen_string_literal: true

module Foundation
  # Web application manifest built from the product identity (SPEC M10.2).
  #
  # Nothing here is hardcoded: name, description, and both colors come from
  # config/foundation.yml, so stamping an identity with bin/rename (or editing
  # that file) updates the installed application's name, splash screen, and
  # theme without touching this class.
  class WebManifest
    SHORT_NAME_LIMIT = 12

    def initialize(identity)
      @identity = identity
    end

    def as_json(*)
      {
        "id" => "/",
        "name" => application_name,
        "short_name" => short_name,
        "description" => description,
        "start_url" => "/",
        "scope" => "/",
        "display" => "standalone",
        "theme_color" => theme_color,
        "background_color" => theme_color,
        "icons" => icons
      }
    end

    def to_json(*args)
      as_json.to_json(*args)
    end

    def theme_color
      AppIcon.normalize_color(@identity[:brand_seed_color])
    end

    private

    def application_name
      @identity[:application_name].to_s.strip.presence || "Application"
    end

    def description
      @identity[:default_page_description].to_s.strip
    end

    # Home-screen labels are truncated by the launcher anyway; cut on a word
    # boundary so the short name stays readable and deterministic.
    def short_name
      return application_name if application_name.length <= SHORT_NAME_LIMIT

      truncated = application_name[0, SHORT_NAME_LIMIT]
      truncated = truncated[0, truncated.rindex(" ")] if truncated.include?(" ")
      truncated.strip
    end

    def icons
      %w[any maskable].map do |purpose|
        { "src" => "/icon.svg", "type" => "image/svg+xml", "sizes" => "any", "purpose" => purpose }
      end
    end
  end
end
