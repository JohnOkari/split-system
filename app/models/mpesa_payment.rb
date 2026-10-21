class MpesaPayment < ApplicationRecord
  has_one :split_allocation, dependent: :restrict_with_exception
  has_many :ledger_entries, dependent: :restrict_with_exception

  validates :mpesa_receipt, presence: true, uniqueness: true
  validates :shortcode, :status, presence: true
  validates :amount_kes, numericality: { only_integer: true, greater_than: 0 }
end
