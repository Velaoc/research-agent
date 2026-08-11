# Sitemap definition for the sitemap_generator gem.
#
# Regenerate in production with:
#   bin/rails sitemap:refresh          # writes public/sitemap.xml.gz and pings search engines
#   bin/rails sitemap:refresh:no_ping  # writes without pinging
#
# The canonical host comes from config/foundation.yml (`domain`).
SitemapGenerator::Sitemap.default_host = "https://#{Rails.configuration.x.foundation[:domain]}"

SitemapGenerator::Sitemap.create do
  # The root path is included automatically. Register additional public
  # pages here as they land, for example:
  #
  #   add "/legal/terms", changefreq: "monthly"
  #   add "/legal/privacy", changefreq: "monthly"
end
