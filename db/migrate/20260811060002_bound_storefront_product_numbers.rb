class BoundStorefrontProductNumbers < ActiveRecord::Migration[8.1]
  def change
    add_check_constraint :storefront_products, "price_cents <= 999999999",
      name: "storefront_products_price_bounded"
    add_check_constraint :storefront_products, "inventory_quantity <= 1000000",
      name: "storefront_products_inventory_bounded"
    add_check_constraint :storefront_products, "position <= 1000000",
      name: "storefront_products_position_bounded"
  end
end
