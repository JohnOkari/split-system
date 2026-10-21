class MpesaOutboxEvent < ApplicationRecord
  validates :event_type, :deduplication_key, presence: true
end
