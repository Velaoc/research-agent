# frozen_string_literal: true

module Foundation
  module Native
    # Deep-link association documents built only from foundation.yml.
    # Unconfigured identifiers yield nil so controllers can 404 cleanly.
    #
    # Apple: apple-app-site-association (Universal Links)
    # Google: assetlinks.json (Android App Links / Digital Asset Links)
    module Associations
      module_function

      def apple_app_site_association
        return nil unless Native.apple_association_configured?

        {
          "applinks" => {
            "apps" => [],
            "details" => [
              {
                "appID" => Native.ios_app_id,
                "paths" => Native.ios_paths
              }
            ]
          }
        }
      end

      def assetlinks
        return nil unless Native.android_association_configured?

        [
          {
            "relation" => [ "delegate_permission/common.handle_all_urls" ],
            "target" => {
              "namespace" => "android_app",
              "package_name" => Native.android_package_name,
              "sha256_cert_fingerprints" => Native.android_sha256_cert_fingerprints
            }
          }
        ]
      end
    end
  end
end
