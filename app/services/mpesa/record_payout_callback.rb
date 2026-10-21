require "digest"

module Mpesa
  class RecordPayoutCallback
    def result(payload)
      body = payload.to_h.stringify_keys.fetch("Result")
      originator = body.fetch("OriginatorConversationID").to_s
      code = body.fetch("ResultCode").to_s
      record_once("b2c_result:#{originator}:#{code}", "b2c_result", body) do
        ProcessPayoutResult.new.call(body)
      end
    end

    def timeout(payload)
      body = payload.to_h.stringify_keys["Result"] || payload.to_h.stringify_keys
      originator = body["OriginatorConversationID"].to_s
      raise KeyError, "Missing OriginatorConversationID" if originator.blank?

      record_once("b2c_timeout:#{originator}", "b2c_timeout", body) do
        payout = MpesaPayout.find_by!(originator_conversation_id: originator)
        payout.with_lock do
          payout.update!(status: "unknown") unless payout.succeeded? || payout.failed?
        end
      end
    end

    private

    def record_once(key, event_type, body)
      event = MpesaCallbackEvent.find_or_create_by!(deduplication_key: key) do |record|
        record.event_type = event_type
        record.payload = body
      end
      return event if event.processed_at?

      yield
      event.update!(processing_status: "processed", processed_at: Time.current, processing_error: nil)
      event
    rescue ActiveRecord::RecordNotUnique
      MpesaCallbackEvent.find_by!(deduplication_key: key)
    rescue KeyError, ActiveRecord::RecordNotFound => error
      event&.update!(processing_status: "needs_review", processing_error: error.class.name)
      raise
    end
  end
end
