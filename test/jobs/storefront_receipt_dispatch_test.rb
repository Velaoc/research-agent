require "test_helper"

class StorefrontReceiptDispatchTest < ActiveJob::TestCase
  test "failed receipt enqueue is repaired durably and normal replay does not duplicate" do
    order = create_storefront_order
    failure = ->(*) { raise ActiveJob::EnqueueError, "queue unavailable" }
    assert_raises(ActiveJob::EnqueueError) do
      with_stubbed_singleton_method(Foundation::Storefront::OrderReceiptJob, :perform_later, failure) do
        Foundation::Storefront::FulfillOrder.call(
          order: order, session_id: nil,
          payment_id: "simulation_payment_#{order.public_reference}", simulated: true
        )
      end
    end
    assert_predicate order.reload, :fulfilled?
    assert_nil order.receipt_queued_at

    assert_enqueued_jobs 1, only: Foundation::Storefront::OrderReceiptJob do
      Foundation::Storefront::RepairReceiptDispatchesJob.perform_now
    end
    assert_predicate order.reload, :receipt_queued_at?

    assert_no_enqueued_jobs do
      Foundation::Storefront::FulfillOrder.call(
        order: order, session_id: nil,
        payment_id: "simulation_payment_#{order.public_reference}", simulated: true
      )
    end
  end

  test "older failed dispatcher cannot clear a newer receipt lease" do
    order = create_storefront_order
    order.update!(state: "fulfilled", paid_at: Time.current, fulfilled_at: Time.current,
      simulated: true, provider_payment_id: "simulation_lease", receipt_queued_at: 1.hour.ago)
    newer_lease = 1.minute.from_now
    failure = lambda do |*|
      order.class.where(id: order.id).update_all(receipt_queued_at: newer_lease)
      raise ActiveJob::EnqueueError, "old claimant failed"
    end
    assert_raises(ActiveJob::EnqueueError) do
      with_stubbed_singleton_method(Foundation::Storefront::OrderReceiptJob, :perform_later, failure) do
        Foundation::Storefront::ReceiptDispatcher.call(order)
      end
    end
    assert_in_delta newer_lease, order.reload.receipt_queued_at, 0.001
  end

  test "duplicate receipt jobs serialize and deliver once with stable message id" do
    order = create_storefront_order
    order.update!(state: "fulfilled", paid_at: Time.current, fulfilled_at: Time.current,
      simulated: true, provider_payment_id: "simulation_delivery")
    assert_difference -> { ActionMailer::Base.deliveries.size }, 1 do
      Foundation::Storefront::OrderReceiptJob.perform_now(order.id)
      Foundation::Storefront::OrderReceiptJob.perform_now(order.id)
    end
    assert_equal "storefront-order-#{order.public_reference}@example.com",
      ActionMailer::Base.deliveries.last.message_id
  end
end

class StorefrontReceiptConcurrencyTest < ActiveSupport::TestCase
  setup do
    @product, @order = committed do
      product = create_storefront_product
      order = create_storefront_order(product: product)
      order.update!(state: "fulfilled", paid_at: Time.current, fulfilled_at: Time.current,
        simulated: true, provider_payment_id: "simulation_concurrent_#{SecureRandom.hex(8)}")
      [ product, order ]
    end
  end

  teardown do
    committed do
      @order.destroy! if @order&.persisted?
      @product.destroy! if @product&.persisted?
    end
  end

  test "concurrent receipt jobs contend on the order lock and deliver once" do
    entered_delivery = Queue.new
    release_delivery = Queue.new
    results = Queue.new
    deliveries = 0
    counter_lock = Mutex.new
    delivery = Object.new
    delivery.define_singleton_method(:deliver_now) do
      counter_lock.synchronize { deliveries += 1 }
      entered_delivery << true
      release_delivery.pop
    end
    replacement = ->(*) { delivery }

    with_stubbed_singleton_method(Foundation::Storefront::OrderMailer, :receipt, replacement) do
      first = receipt_thread(results)
      entered_delivery.pop
      second = receipt_thread(results)
      # The second job has a separate database connection and must contend on
      # the row lock held while the first delivery remains in progress.
      assert second.alive?
      release_delivery << true
      assert first.join(10), "first receipt job did not finish"
      assert second.join(10), "second receipt job did not finish"
    end

    failures = 2.times.map { results.pop }.compact
    flunk failures.first.full_message if failures.any?
    assert_equal 1, deliveries
    assert_predicate @order.reload, :receipt_sent_at?
  end

  private

  def committed(&block)
    result = Queue.new
    Thread.new do
      ActiveRecord::Base.connection_pool.with_connection { result << [ :ok, block.call ] }
    rescue StandardError => error
      result << [ :error, error ]
    end.join
    status, value = result.pop
    raise value if status == :error

    value
  end

  def receipt_thread(results)
    Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do
        Foundation::Storefront::OrderReceiptJob.perform_now(@order.id)
        results << nil
      rescue StandardError => error
        results << error
      end
    end
  end
end
