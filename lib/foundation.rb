# frozen_string_literal: true

require_relative "foundation/modules"

# Namespace for original foundation code (SPEC global conventions).
module Foundation
  PLACEHOLDER_MARKERS = %w[placeholder your_ dummy no_egress disabled].freeze

  # True when a generation-time module still has a manifest on disk.
  # Omitted modules delete their manifest; see docs/MODULES.md.
  def self.module_available?(name, root: Rails.root)
    Modules.available?(name, root: root)
  end

  # foundation:module storefront
  def self.storefront_enabled?
    Rails.configuration.x.foundation[:storefront_enabled] == true
  end
  # /foundation:module storefront

  def self.preview?
    runtime_config.preview?
  end

  # foundation:module storefront
  def self.storefront_simulator?
    storefront_enabled? && runtime_config.simulator?
  end

  def self.storefront_preview_stripe?
    storefront_enabled? && runtime_config.preview_stripe?
  end
  # /foundation:module storefront

  # True when the app is running as a hosted Holodex preview that has no
  # SMTP relay configured (SPEC M2.5 / M9.3). The preview flag is injected
  # by the Holodex runtime; a generated app never sets it itself.
  #
  # In this state outbound mail is impossible (previews have no egress), so
  # flows that would otherwise depend on delivering an email — most notably
  # Devise's confirmation step — must degrade gracefully. Later milestones
  # (M8 checkout simulator, M9 mail selection) reuse this same predicate so
  # the definition lives in exactly one place.
  def self.offline_preview?
    runtime_config.offline_preview?
  end

  def self.runtime_config
    Rails.configuration.x.runtime_config
  end
end
