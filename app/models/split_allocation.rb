class SplitAllocation < ApplicationRecord
  belongs_to :mpesa_payment
  has_one :mpesa_payout, dependent: :restrict_with_exception

  validates :retained_kes, :recipient_kes,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :shares_match_payment

  private

  def shares_match_payment
    return unless mpesa_payment
    return if retained_kes.to_i + recipient_kes.to_i == mpesa_payment.amount_kes

    errors.add(:base, "Split must equal the payment amount")
  end
end
