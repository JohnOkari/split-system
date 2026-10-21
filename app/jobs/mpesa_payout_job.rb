class MpesaPayoutJob < ApplicationJob
  queue_as :payments

  def perform(payout_id)
    Mpesa::SubmitPayout.new.call(payout_id)
  end
end
