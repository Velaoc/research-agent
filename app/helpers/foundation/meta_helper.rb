module Foundation
  module MetaHelper
    # Renders the <title> and meta/Open Graph tags for the current page,
    # falling back to the product identity in config/foundation.yml.
    # Individual pages override any of it with set_meta_tags (meta-tags gem).
    def foundation_meta_tags
      identity = Rails.configuration.x.foundation

      defaults = {
        site: identity[:application_name],
        title: identity[:default_page_title],
        description: identity[:default_page_description],
        og: {
          site_name: identity[:application_name],
          title: :title,
          description: :description,
          type: "website"
        }
      }
      defaults[:og][:image] = identity[:default_og_image_url] if identity[:default_og_image_url].present?

      display_meta_tags(defaults)
    end
  end
end
