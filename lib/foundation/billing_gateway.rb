# frozen_string_literal: true

module Foundation
  module BillingGateway
    module_function

    def checkout_url(organization:, price_id:, success_url:, cancel_url:)
      organization.set_payment_processor(:stripe)
      session = organization.payment_processor.checkout(
        mode: "subscription",
        locale: I18n.locale,
        line_items: [ { price: price_id, quantity: 1 } ],
        subscription_data: { metadata: { organization_id: organization.id } },
        success_url: success_url,
        cancel_url: cancel_url
      )
      session.url
    end

    def portal_url(organization:, return_url:)
      organization.payment_processor.billing_portal(return_url: return_url).url
    end
  end
end
