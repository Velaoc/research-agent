require "test_helper"

class StorefrontOrderMailerTest < ActionMailer::TestCase
  include ActiveSupport::Testing::TimeHelpers
  test "fulfilled order receipt contains private status and legal links without card data" do
    order = create_storefront_order
    Foundation::Storefront::FulfillOrder.call(
      order: order, session_id: nil, payment_id: "simulation_payment_#{order.public_reference}", simulated: true
    )
    mail = Foundation::Storefront::OrderMailer.receipt(order)
    assert_equal [ order.email ], mail.to
    assert_match order.public_reference, mail.subject
    assert_match %r{/storefront/orders/#{order.public_reference}}, mail.body.encoded
    assert_match(/access_token/, mail.body.encoded)
    assert_match(/Terms/, mail.body.encoded)
    assert_no_match(/card number|CVC/i, mail.body.encoded)
  end

  test "delayed fulfillment email issues a fresh receipt capability" do
    order = create_storefront_order
    travel 2.days
    mail = Foundation::Storefront::OrderMailer.receipt(order)
    document = Nokogiri::HTML(mail.html_part.body.decoded)
    receipt_link = document.css("a").find { |link| link.text.include?("View your receipt") }
    token = Rack::Utils.parse_query(URI.parse(receipt_link["href"]).query).fetch("access_token")
    assert Foundation::Storefront::ReceiptAccess.allowed?(order: order, user: nil, token: token)
    travel 25.hours
    assert_not Foundation::Storefront::ReceiptAccess.allowed?(order: order, user: nil, token: token)
  end
end
