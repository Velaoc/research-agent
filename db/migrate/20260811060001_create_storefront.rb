class CreateStorefront < ActiveRecord::Migration[8.1]
  def change
    create_table :storefront_products do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.string :sku, null: false
      t.text :description, null: false, default: ""
      t.bigint :price_cents, null: false
      t.string :currency, limit: 3, null: false, default: "USD"
      t.boolean :active, null: false, default: true
      t.integer :inventory_quantity, null: false, default: 0
      t.integer :position, null: false, default: 0
      t.string :image_url
      t.timestamps

      t.index :slug, unique: true
      t.index :sku, unique: true
      t.index %i[active position]
      t.check_constraint "price_cents >= 0", name: "storefront_products_price_nonnegative"
      t.check_constraint "inventory_quantity >= 0", name: "storefront_products_inventory_nonnegative"
      t.check_constraint "position >= 0", name: "storefront_products_position_nonnegative"
      t.check_constraint "currency = upper(currency) AND currency ~ '^[A-Z]{3}$'", name: "storefront_products_currency_format"
      t.check_constraint "length(btrim(name)) > 0", name: "storefront_products_name_present"
      t.check_constraint "length(btrim(slug)) > 0", name: "storefront_products_slug_present"
      t.check_constraint "length(btrim(sku)) > 0", name: "storefront_products_sku_present"
    end

    create_table :storefront_orders do |t|
      t.string :public_reference, null: false
      t.references :user, foreign_key: { on_delete: :nullify }
      t.string :email, null: false
      t.string :state, null: false, default: "pending"
      t.string :currency, limit: 3, null: false
      t.bigint :subtotal_cents, null: false
      t.bigint :total_cents, null: false
      t.string :terms_version, null: false
      t.string :privacy_version, null: false
      t.datetime :legal_accepted_at, null: false
      t.string :acceptance_ip
      t.string :acceptance_user_agent
      t.string :stripe_session_id
      t.string :provider_payment_id
      t.boolean :simulated, null: false, default: false
      t.datetime :reservation_expires_at, null: false
      t.datetime :inventory_released_at
      t.datetime :checkout_started_at
      t.datetime :paid_at
      t.datetime :fulfilled_at
      t.datetime :canceled_at
      t.datetime :refunded_at
      t.datetime :receipt_queued_at
      t.datetime :receipt_sent_at
      t.timestamps

      t.index :public_reference, unique: true
      t.index :stripe_session_id, unique: true, where: "stripe_session_id IS NOT NULL"
      t.index :provider_payment_id, unique: true, where: "provider_payment_id IS NOT NULL"
      t.index %i[state created_at]
      t.index %i[state reservation_expires_at]
      t.index %i[user_id created_at]
      t.check_constraint "state IN ('pending','paid','fulfilled','canceled','refunded')", name: "storefront_orders_state_allowed"
      t.check_constraint "subtotal_cents >= 0 AND total_cents >= 0", name: "storefront_orders_totals_nonnegative"
      t.check_constraint "subtotal_cents = total_cents", name: "storefront_orders_total_matches_subtotal"
      t.check_constraint "currency = upper(currency) AND currency ~ '^[A-Z]{3}$'", name: "storefront_orders_currency_format"
      t.check_constraint "length(btrim(email)) > 0", name: "storefront_orders_email_present"
    end

    create_table :storefront_line_items do |t|
      t.references :order, null: false, foreign_key: { to_table: :storefront_orders, on_delete: :cascade }
      t.references :product, foreign_key: { to_table: :storefront_products, on_delete: :nullify }
      t.string :name, null: false
      t.string :sku, null: false
      t.bigint :unit_price_cents, null: false
      t.string :currency, limit: 3, null: false
      t.integer :quantity, null: false
      t.bigint :line_total_cents, null: false
      t.timestamps

      t.index %i[order_id product_id]
      t.check_constraint "unit_price_cents >= 0 AND line_total_cents >= 0", name: "storefront_line_items_prices_nonnegative"
      t.check_constraint "quantity BETWEEN 1 AND 10", name: "storefront_line_items_quantity_range"
      t.check_constraint "line_total_cents = unit_price_cents * quantity", name: "storefront_line_items_total_matches"
      t.check_constraint "currency = upper(currency) AND currency ~ '^[A-Z]{3}$'", name: "storefront_line_items_currency_format"
      t.check_constraint "length(btrim(name)) > 0 AND length(btrim(sku)) > 0", name: "storefront_line_items_snapshot_present"
    end

    create_table :storefront_payment_events do |t|
      t.references :order, foreign_key: { to_table: :storefront_orders, on_delete: :nullify }
      t.string :provider, null: false
      t.string :provider_event_id, null: false
      t.string :event_type, null: false
      t.string :status, null: false, default: "received"
      t.string :provider_session_id
      t.string :provider_payment_id
      t.string :error_code
      t.string :payload_digest, null: false
      t.datetime :processed_at
      t.timestamps

      t.index %i[provider provider_event_id], unique: true
      t.index %i[provider_session_id created_at]
      t.index %i[provider_payment_id created_at]
      t.index %i[status created_at]
      t.check_constraint "status IN ('received','processed','rejected','ignored')", name: "storefront_payment_events_status_allowed"
      t.check_constraint "length(btrim(provider_event_id)) > 0", name: "storefront_payment_events_id_present"
    end
  end
end
