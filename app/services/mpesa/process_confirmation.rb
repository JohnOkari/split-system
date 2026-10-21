require "bigdecimal"

module Mpesa
  class ProcessConfirmation
    def call(payload)
      fields = payload.to_h.stringify_keys
      receipt = required(fields, "TransID")
      shortcode = required(fields, "BusinessShortCode")
      amount = parse_amount(required(fields, "TransAmount"))
      config = Configuration.new
      raise ArgumentError, "Unexpected Paybill shortcode" unless shortcode == config.fetch(:paybill_shortcode).to_s

      payment_id = nil
      MpesaPayment.transaction do
        payment = MpesaPayment.create!(
          mpesa_receipt: receipt,
          shortcode: shortcode,
          amount_kes: amount,
          bill_reference: fields["BillRefNumber"].to_s.presence,
          status: "received",
          received_at: Time.current
        )
        recipient_share = amount / 2
        retained_share = amount - recipient_share
        allocation = payment.create_split_allocation!(retained_kes: retained_share, recipient_kes: recipient_share)
        payout = allocation.create_mpesa_payout!(
          recipient_phone: config.recipient_phone,
          amount_kes: recipient_share,
          status: "pending"
        ) if recipient_share.positive?

        [
          ["mpesa_clearing", "debit", amount, "payment:#{receipt}:clearing"],
          ["retained_share", "credit", retained_share, "payment:#{receipt}:retained"],
          ["recipient_payable", "credit", recipient_share, "payment:#{receipt}:recipient"]
        ].each do |account, type, value, event_key|
          next if value.zero?
          payment.ledger_entries.create!(account_code: account, entry_type: type, amount_kes: value, event_key: event_key)
        end

        MpesaOutboxEvent.create!(
          event_type: "submit_payout",
          deduplication_key: "payout:#{payout.id}:submit",
          payload: { payout_id: payout.id }
        ) if payout
        payment_id = payment.id
      end

      { accepted: true, payment_id: payment_id }
    rescue ActiveRecord::RecordNotUnique
      existing = MpesaPayment.find_by(mpesa_receipt: receipt) if receipt.present?
      raise unless existing

      { accepted: true, duplicate: true, payment_id: existing.id }
    end

    private

    def required(payload, key)
      value = payload[key].to_s.strip
      raise ArgumentError, "Missing #{key}" if value.blank?
      value
    end

    def parse_amount(value)
      amount = BigDecimal(value.to_s)
      unless amount.positive? && amount.frac.zero? && amount <= 9_007_199_254_740_991
        raise ArgumentError, "Invalid payment amount"
      end
      amount.to_i
    rescue ArgumentError
      raise ArgumentError, "Invalid payment amount"
    end
  end
end
