# frozen_string_literal: true

module Foundation
  module Admin
    class ProductsController < BaseController
      layout "madmin/application"
      before_action :require_storefront!
      before_action :set_product, only: %i[show edit update set_availability adjust_inventory]

      def index
        @products = Storefront::Product.order(:position, :name, :id).limit(250).with_attached_image
      end

      def show; end

      def new
        @product = Storefront::Product.new(currency: "USD", active: true, inventory_quantity: 0, position: 0)
      end

      def create
        @product = Storefront::Product.new(product_attributes)
        foundation_admin_audit_subject(@product)
        if @product.save
          foundation_admin_audit_subject(@product)
          redirect_to storefront_admin_product_path(@product), notice: "Product created."
        else
          render :new, status: :unprocessable_content
        end
      end

      def edit; end

      def update
        foundation_admin_audit_subject(@product)
        if @product.update(product_attributes)
          redirect_to storefront_admin_product_path(@product), notice: "Product updated."
        else
          render :edit, status: :unprocessable_content
        end
      end

      def set_availability
        foundation_admin_audit_subject(@product)
        raw_active = params.require(:active).to_s
        raise ArgumentError unless %w[true false].include?(raw_active)
        active = raw_active == "true"
        @product.update!(active: active)
        redirect_to storefront_admin_product_path(@product), notice: active ? "Product made available." : "Product hidden."
      rescue ArgumentError
        foundation_admin_audit_outcome(:rejected)
        redirect_to storefront_admin_product_path(@product), alert: "Availability must be true or false."
      end

      def adjust_inventory
        foundation_admin_audit_subject(@product)
        quantity = Integer(params.require(:inventory_quantity), 10)
        raise ArgumentError unless quantity.between?(0, 1_000_000)

        @product.with_lock { @product.update!(inventory_quantity: quantity) }
        redirect_to storefront_admin_product_path(@product), notice: "Inventory updated."
      rescue ArgumentError
        foundation_admin_audit_outcome(:rejected)
        redirect_to storefront_admin_product_path(@product), alert: "Inventory must be an integer from 0 to 1,000,000."
      end

      def import
        upload = params.require(:csv)
        raise ArgumentError, "Select a CSV file." unless upload.respond_to?(:read)
        raise ArgumentError, "CSV is larger than 1 MB." if upload.size > Storefront::CsvImporter::MAX_BYTES

        foundation_admin_audit_bulk_subject("Foundation::Storefront::Product")
        @result = Storefront::CsvImporter.call(upload.read)
        foundation_admin_audit_details(created: @result.created, updated: @result.updated, errors: @result.errors)
        foundation_admin_audit_outcome(:partial) if @result.errors.positive?
        render :import_result
      rescue ActionController::ParameterMissing, ArgumentError => error
        foundation_admin_audit_bulk_subject("Foundation::Storefront::Product")
        foundation_admin_audit_outcome(:rejected)
        redirect_to storefront_admin_products_path, alert: error.message
      end

      private

      def require_storefront!
        head :not_found unless Foundation.storefront_enabled?
      end

      def set_product
        @product = Storefront::Product.find(params[:id])
      end

      def product_attributes
        params.require(:product).permit(
          :name, :slug, :sku, :description, :price_cents, :currency,
          :image_url, :image, :position
        )
      end
    end
  end
end
