# frozen_string_literal: true

module Foundation
  # Optional demo catalog rows (SPEC M10.3).
  #
  # The application boots and serves every page with an empty database, so no
  # seed is ever required. These rows exist only to make the storefront and
  # checkout walkable on a developer machine or in a hosted preview, and they
  # are refused everywhere else — a production deployment must never find
  # invented products in its catalog.
  module DemoSeeds
    PRODUCTS = [
      {
        slug: "starter-license", sku: "DEMO-STARTER", name: "Starter license",
        description: "Demo catalog row: a single-seat license for the example product.",
        price_cents: 2_900, position: 0, inventory_quantity: 100
      },
      {
        slug: "team-license", sku: "DEMO-TEAM", name: "Team license",
        description: "Demo catalog row: a five-seat license for the example product.",
        price_cents: 9_900, position: 1, inventory_quantity: 50
      },
      {
        slug: "reference-guide", sku: "DEMO-GUIDE", name: "Reference guide",
        description: "Demo catalog row: a downloadable guide delivered after checkout.",
        price_cents: 1_500, position: 2, inventory_quantity: 250
      }
    ].freeze

    # Development or a hosted preview only. Preview runs in the production
    # Rails environment, so the preview flag — not RAILS_ENV alone — is what
    # separates a disposable demo from a real deployment.
    def self.permitted?(rails_env: Rails.env, preview: Foundation.preview?)
      rails_env.development? || preview
    end

    def self.run!(io: $stdout)
      unless permitted?
        io.puts("Skipping demo seeds: they are limited to development and hosted previews.")
        return 0
      end

      unless Foundation.storefront_enabled?
        io.puts("Skipping demo seeds: the storefront is disabled in config/foundation.yml.")
        return 0
      end

      created = seed_products!
      io.puts("Demo catalog ready: #{PRODUCTS.length} products (#{created} created).")
      created
    end

    # Upserts by slug so repeated runs converge on the same catalog instead of
    # duplicating rows.
    def self.seed_products!
      created = 0

      PRODUCTS.each do |attributes|
        product = Foundation::Storefront::Product.find_or_initialize_by(slug: attributes[:slug])
        created += 1 if product.new_record?
        product.update!(**attributes, currency: "USD", active: true)
      end

      created
    end
  end
end
