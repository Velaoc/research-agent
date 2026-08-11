# frozen_string_literal: true

module Foundation
  module Storefront
    class ProductsController < BaseController
      def index
        @page = Integer(params.fetch(:page, 1), 10, exception: false).to_i.clamp(1, 1_000)
        rows = Product.catalog.offset((@page - 1) * 24).limit(25).with_attached_image.to_a
        @has_next_page = rows.length > 24
        @products = rows.first(24)
      end

      def show
        @product = Product.catalog.with_attached_image.find_by!(slug: params[:slug])
      end

      def image
        product = Product.catalog.with_attached_image.find_by!(slug: params[:slug])
        head :not_found and return unless product.image.attached?

        expires_in 1.hour, public: true
        send_data product.image.download,
          type: product.image.blob.content_type,
          disposition: "inline",
          filename: product.image.filename.to_s
      end
    end
  end
end
