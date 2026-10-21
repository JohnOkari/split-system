class MpesaStaleSubmissionRecoveryJob < ApplicationJob
  queue_as :payments

  def perform
    MpesaPayout.where(status: "submitting").where("claimed_at < ?", 10.minutes.ago).find_each do |payout|
      payout.with_lock do
        next unless payout.submitting? && payout.claimed_at < 10.minutes.ago

        payout.update!(status: "unknown")
        payout.attempt_records.where(status: "submitting").update_all(
          status: "unknown", error_message: "Worker stopped before the outcome was recorded", updated_at: Time.current
        )
      end
    end
  end
end
