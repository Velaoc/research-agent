# frozen_string_literal: true

module Foundation
  module StorefrontHelper
    def storefront_money(cents, currency)
      whole, fraction = Integer(cents).divmod(100)
      "#{currency} #{whole}.#{format('%02d', fraction)}"
    end

    def storefront_product_image(product, alt:, class_name: nil)
      attributes = { alt: alt, class: class_name, loading: "lazy", decoding: "async" }
      if product.image.attached?
        image_tag(storefront_image_product_path(product.slug), **attributes)
      elsif product.external_image?
        image_tag(product.image_url, **attributes, referrerpolicy: "no-referrer")
      else
        tag.div("No image available", class: class_names(class_name, "storefront-image-placeholder"), role: "img", aria: { label: alt })
      end
    end
  end
end
