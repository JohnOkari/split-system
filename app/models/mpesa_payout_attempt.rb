class MpesaPayoutAttempt < ApplicationRecord
  belongs_to :mpesa_payout
  validates :originator_conversation_id, :status, presence: true
end
