Rails.application.configure do
  # Keep queue inserts in the same PostgreSQL transaction as outbox dispatch markers.
  config.good_job.enqueue_after_transaction_commit = false
  config.good_job.enable_cron = true
  config.good_job.cron = {
    mpesa_outbox_dispatch: {
      cron: "* * * * *",
      class: "MpesaOutboxDispatchJob",
      description: "Dispatch durable M-Pesa payout events"
    },
    mpesa_stale_submission_recovery: {
      cron: "*/5 * * * *",
      class: "MpesaStaleSubmissionRecoveryJob",
      description: "Mark interrupted submissions unknown for manual reconciliation"
    }
  }
end
