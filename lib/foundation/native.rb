# frozen_string_literal: true

module Foundation
  # Server contract for Hotwire Native shells (SPEC M14). Configuration is
  # read from config/foundation.yml under the `native` key; association
  # identifiers are never hardcoded.
  module Native
    PLATFORMS = %w[ios android].freeze
    PATH_CONFIGURATION_VERSION = 1
    # Same marker turbo-rails uses for hotwire_native_app?.
    USER_AGENT_PATTERN = /(Turbo|Hotwire) Native/

    module_function

    def config
      raw = Rails.configuration.x.foundation[:native]
      return {}.with_indifferent_access if raw.blank?

      raw.with_indifferent_access
    end

    def shell?(user_agent)
      user_agent.to_s.match?(USER_AGENT_PATTERN)
    end

    def ios_app_id
      config[:ios_app_id].to_s.strip.presence
    end

    def ios_paths
      paths = Array(config[:ios_paths]).map { |path| path.to_s.strip }.reject(&:blank?)
      paths.presence || [ "*" ]
    end

    def android_package_name
      config[:android_package_name].to_s.strip.presence
    end

    def android_sha256_cert_fingerprints
      Array(config[:android_sha256_cert_fingerprints]).map { |value| value.to_s.strip }.reject(&:blank?)
    end

    def apple_association_configured?
      ios_app_id.present?
    end

    def android_association_configured?
      android_package_name.present? && android_sha256_cert_fingerprints.any?
    end
  end
end
