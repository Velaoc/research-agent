# frozen_string_literal: true

# Regenerates public/sitemap.xml.gz from config/sitemap.rb without pinging
# search engines. Schedule daily (see config/recurring.yml).
class SitemapRefreshJob < ApplicationJob
  queue_as :default

  def perform
    SitemapGenerator.verbose = false
    SitemapGenerator::Interpreter.run
  end
end
