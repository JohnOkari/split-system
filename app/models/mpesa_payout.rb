class MpesaPayout < ApplicationRecord
  belongs_to :split_allocation
  has_many :attempt_records, class_name: "MpesaPayoutAttempt", dependent: :restrict_with_exception

  enum :status, {
    pending: "pending", submitting: "submitting", processing: "processing",
    succeeded: "succeeded", failed: "failed", unknown: "unknown", awaiting_funds: "awaiting_funds"
  }

  validates :recipient_phone, :status, presence: true
  validates :amount_kes, numericality: { only_integer: true, greater_than: 0 }
end
