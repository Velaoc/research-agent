class AddStorefrontCheckoutIdempotencyAndThrottling < ActiveRecord::Migration[8.1]
  def change
    add_column :storefront_orders, :checkout_key_digest, :string, null: false
    add_index :storefront_orders, :checkout_key_digest, unique: true

    create_table :storefront_checkout_attempts do |t|
      t.string :key_digest, null: false
      t.string :kind, null: false
      t.datetime :created_at, null: false

      t.index %i[kind key_digest created_at], name: "index_storefront_checkout_attempts_lookup"
      t.index :created_at
      t.check_constraint "kind IN ('session','ip')", name: "storefront_checkout_attempts_kind_allowed"
    end
  end
end
