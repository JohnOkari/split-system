require "digest"

module Mpesa
  class RecordConfirmation
    def call(payload)
      fields = payload.to_h.stringify_keys.slice(
        "TransID", "BusinessShortCode", "TransAmount", "BillRefNumber", "TransTime"
      )
      receipt = fields["TransID"].to_s.presence
      key = receipt || Digest::SHA256.hexdigest(fields.to_json)
      event = MpesaCallbackEvent.find_or_create_by!(deduplication_key: "c2b:#{key}") do |record|
        record.event_type = "c2b_confirmation"
        record.payload = fields
      end
      return event if event.processed_at?

      begin
        ProcessConfirmation.new.call(fields)
        event.update!(processing_status: "processed", processed_at: Time.current, processing_error: nil)
      rescue ArgumentError, KeyError, ActiveRecord::RecordInvalid => error
        event.update!(processing_status: "needs_review", processing_error: error.class.name)
        Rails.logger.warn("M-Pesa C2B callback needs review event_id=#{event.id} error=#{error.class.name}")
      end
      event
    end
  end
end
