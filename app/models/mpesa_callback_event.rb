class MpesaCallbackEvent < ApplicationRecord
  validates :event_type, :deduplication_key, :processing_status, presence: true
end
