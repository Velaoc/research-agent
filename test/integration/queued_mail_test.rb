require "test_helper"

# SPEC M9: a hosted preview is a single container, so `SOLID_QUEUE_IN_PUMA=1`
# runs the queue supervisor inside the web process. Mail that an application
# hands to Active Job must therefore still reach a real delivery — an enqueued
# receipt that nothing ever performs would leave a preview silently mailless.
class QueuedMailTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  test "single container previews run the queue inside Puma" do
    with_env("SOLID_QUEUE_IN_PUMA" => "1") do
      assert_predicate Foundation.runtime_config, :solid_queue_in_puma?
      assert_equal "inside Puma", Foundation.runtime_config.queue_mode
    end

    with_env("SOLID_QUEUE_IN_PUMA" => nil) do
      assert_not_predicate Foundation.runtime_config, :solid_queue_in_puma?
      assert_equal "external worker", Foundation.runtime_config.queue_mode
    end
  end

  # foundation:module storefront
  test "mail handed to the queue is enqueued and then actually delivered" do
    with_queue_in_puma do
      ActionMailer::Base.deliveries.clear

      assert_enqueued_jobs 1, only: ActionMailer::MailDeliveryJob do
        Foundation::Storefront::OrderMailer.receipt(create_storefront_order).deliver_later
      end
      assert_empty ActionMailer::Base.deliveries, "delivery must wait for the queue to run"

      perform_enqueued_jobs
      delivered = ActionMailer::Base.deliveries.last

      assert_equal 1, ActionMailer::Base.deliveries.size
      assert_match %r{https://queued\.canonical\.example/storefront/orders/}, delivered.body.encoded
      assert_equal [ "queue@queued.canonical.example" ], delivered.from
    end
  end

  # The storefront's own receipt path is queued rather than inline, so the
  # enqueue/perform contract covers a real application flow end to end.
  test "a fulfilled order delivers its receipt once the queue runs" do
    with_queue_in_puma do
      ActionMailer::Base.deliveries.clear
      order = create_storefront_order

      assert_enqueued_jobs 1, only: Foundation::Storefront::OrderReceiptJob do
        Foundation::Storefront::FulfillOrder.call(
          order: order, session_id: nil,
          payment_id: "simulation_payment_#{order.public_reference}", simulated: true
        )
      end
      assert_empty ActionMailer::Base.deliveries

      perform_enqueued_jobs

      assert_predicate order.reload, :receipt_sent_at?
      assert_equal [ order.email ], ActionMailer::Base.deliveries.last.to
    end
  end
  # /foundation:module storefront

  private

  def with_queue_in_puma(&block)
    with_env(
      "SOLID_QUEUE_IN_PUMA" => "1",
      "VELA_HOLODEX_PREVIEW" => "1",
      "APP_HOST" => "https://queued.canonical.example",
      "MAILER_FROM" => "queue@queued.canonical.example",
      "SMTP_ADDRESS" => nil,
      &block
    )
  end
end
