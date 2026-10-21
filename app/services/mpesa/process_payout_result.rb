module Mpesa
  class ProcessPayoutResult
    def call(result)
      originator_id = result.fetch("OriginatorConversationID").to_s
      payout = MpesaPayout.find_by!(originator_conversation_id: originator_id)

      MpesaPayout.transaction do
        payout.lock!
        return payout if payout.succeeded? || payout.failed?

        result_code = result["ResultCode"].to_s
        MpesaPayoutAttempt.where(
          mpesa_payout_id: payout.id,
          originator_conversation_id: originator_id,
          status: %w[submitting accepted unknown]
        ).update_all(status: result_code == "0" ? "succeeded" : "failed", updated_at: Time.current)
        payout.update!(
          status: result_code == "0" ? "succeeded" : "failed",
          succeeded_at: result_code == "0" ? Time.current : nil,
          conversation_id: result["ConversationID"].presence || payout.conversation_id,
          mpesa_receipt: transaction_receipt(result).presence || payout.mpesa_receipt,
          result_code: result_code,
          result_description: result["ResultDesc"].to_s.truncate(500)
        )

        if payout.succeeded?
          payment = payout.split_allocation.mpesa_payment
          [
            ["recipient_payable", "debit", "settlement:#{payout.id}:payable"],
            ["mpesa_disbursement", "credit", "settlement:#{payout.id}:disbursement"]
          ].each do |account, type, key|
            payment.ledger_entries.find_or_create_by!(event_key: key) do |entry|
              entry.account_code = account
              entry.entry_type = type
              entry.amount_kes = payout.amount_kes
            end
          end
        end
      end
      payout
    end

    private

    def transaction_receipt(result)
      parameters = result.dig("ResultParameters", "ResultParameter") || []
      Array(parameters).find { |item| item["Key"] == "TransactionReceipt" }&.fetch("Value", nil) || result["TransactionID"]
    end
  end
end
