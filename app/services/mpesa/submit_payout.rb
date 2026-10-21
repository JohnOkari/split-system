require "securerandom"

module Mpesa
  class SubmitPayout
    B2C_PATH = "/mpesa/b2c/v3/paymentrequest".freeze

    def call(payout_id)
      config = Configuration.new
      payout = MpesaPayout.find(payout_id)
      return payout if payout.succeeded? || payout.failed? || payout.processing? || payout.unknown?
      return payout unless config.enabled_for_payouts?
      unless config.funding_available?
        payout.update!(status: "awaiting_funds")
        return payout
      end

      attempt = claim!(payout, config)
      return payout unless attempt

      response = Daraja::Client.new(configuration: config).post(B2C_PATH, request_payload(payout, attempt, config))
      MpesaPayoutAttempt.where(id: attempt.id, status: "submitting").update_all(
        status: "accepted", response_body: response.slice("ResponseCode", "ResponseDescription", "ConversationID", "OriginatorConversationID"),
        submitted_at: Time.current, updated_at: Time.current
      )

      unless response["ResponseCode"].to_s == "0"
        MpesaPayoutAttempt.where(id: attempt.id, status: "accepted").update_all(status: "rejected", updated_at: Time.current)
        MpesaPayout.where(id: payout.id, status: "submitting").update_all(
          status: "failed", result_description: response["ResponseDescription"].to_s.truncate(500), updated_at: Time.current
        )
        return payout.reload
      end

      # Callback can arrive before this response; never overwrite a callback's terminal state.
      MpesaPayout.where(id: payout.id, status: "submitting").update_all(
        status: "processing", conversation_id: response["ConversationID"], updated_at: Time.current
      )
      payout.reload
    rescue Net::OpenTimeout, Net::ReadTimeout, Timeout::Error, Daraja::Client::Error => error
      if error.is_a?(Daraja::Client::Error) && error.http_status && error.http_status < 500
        mark_rejected(payout, attempt, error)
        return payout.reload
      end
      mark_unknown(payout, attempt, error)
      payout.reload
    rescue StandardError => error
      mark_unknown(payout, attempt, error) if attempt
      raise
    end

    private

    def claim!(payout, config)
      attempt = nil
      payout.with_lock do
        return nil unless payout.pending? || payout.awaiting_funds?
        raise ArgumentError, "Payout recipient is not the configured recipient" unless payout.recipient_phone == config.recipient_phone

        originator_id = SecureRandom.hex(8)
        payout.update!(status: "submitting", originator_conversation_id: originator_id,
                       attempts: payout.attempts + 1, claimed_at: Time.current)
        attempt = payout.attempt_records.create!(originator_conversation_id: originator_id, status: "submitting")
      end
      attempt
    end

    def request_payload(payout, attempt, config)
      {
        OriginatorConversationID: attempt.originator_conversation_id,
        InitiatorName: config.fetch(:initiator_name),
        SecurityCredential: config.fetch(:security_credential),
        CommandID: "BusinessPayment",
        Amount: payout.amount_kes,
        PartyA: config.fetch(:b2c_shortcode),
        PartyB: payout.recipient_phone,
        Remarks: "Revenue split #{payout.id}",
        QueueTimeOutURL: config.callback_url(:timeout),
        ResultURL: config.callback_url(:result)
      }
    end

    def mark_unknown(payout, attempt, error)
      MpesaPayoutAttempt.where(id: attempt&.id, status: "submitting").update_all(
        status: "unknown", error_message: error.class.name, updated_at: Time.current
      )
      MpesaPayout.where(id: payout.id, status: "submitting").update_all(status: "unknown", updated_at: Time.current)
    rescue ActiveRecord::RecordNotFound
      nil
    end

    def mark_rejected(payout, attempt, error)
      MpesaPayoutAttempt.where(id: attempt&.id, status: "submitting").update_all(
        status: "rejected", http_status: error.http_status, response_body: error.response_body || {},
        error_message: error.class.name, updated_at: Time.current
      )
      MpesaPayout.where(id: payout.id, status: "submitting").update_all(
        status: "failed", result_description: "Daraja rejected the request (HTTP #{error.http_status})", updated_at: Time.current
      )
    end
  end
end
