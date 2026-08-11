require "test_helper"

class SitemapRefreshJobTest < ActiveJob::TestCase
  test "refreshes the sitemap without pinging search engines" do
    sitemap_path = Rails.root.join("public/sitemap.xml.gz")
    FileUtils.rm_f(sitemap_path)

    pinged = false
    with_stubbed_singleton_method(SitemapGenerator::Sitemap, :ping_search_engines, ->(*) { pinged = true }) do
      SitemapRefreshJob.perform_now
    end

    assert_path_exists sitemap_path
    assert_not pinged, "sitemap refresh must use the no-ping path"
  ensure
    FileUtils.rm_f(sitemap_path)
  end
end
