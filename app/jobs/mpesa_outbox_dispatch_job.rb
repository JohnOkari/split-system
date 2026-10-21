class MpesaOutboxDispatchJob < ApplicationJob
  queue_as :payments

  def perform
    MpesaOutboxEvent.where(dispatched_at: nil).order(:id).find_each do |event|
      event.with_lock do
        next if event.dispatched_at?

        case event.event_type
        when "submit_payout"
          MpesaPayoutJob.perform_later(event.payload.fetch("payout_id"))
        else
          Rails.logger.error("Unknown M-Pesa outbox event id=#{event.id} type=#{event.event_type}")
          next
        end
        event.update!(dispatched_at: Time.current)
      end
    end
  end
end
