class LedgerEntry < ApplicationRecord
  belongs_to :mpesa_payment
  validates :account_code, :entry_type, :event_key, presence: true
  validates :amount_kes, numericality: { only_integer: true, greater_than: 0 }
  validates :entry_type, inclusion: { in: %w[debit credit] }
end
