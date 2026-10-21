require "csv"
require "bigdecimal"
require "date"

module Mpesa
  class ReconcileStatement
    def call(path:, kind:, since:, until_date:)
      raise ArgumentError, "kind must be c2b or b2c" unless %w[c2b b2c].include?(kind)
      start_time = Date.iso8601(since).in_time_zone.beginning_of_day
      end_time = Date.iso8601(until_date).in_time_zone.end_of_day
      raise ArgumentError, "until date must not be before since date" if end_time < start_time

      local_records = kind == "c2b" ? c2b_records(start_time, end_time) : b2c_records(start_time, end_time)
      statement_records = read_statement(path)
      receipts = statement_records.map { |record| record.fetch(:receipt) }
      raise ArgumentError, "Statement contains duplicate receipts" unless receipts.uniq.length == receipts.length

      local_by_receipt = local_records.index_by { |record| record.fetch(:receipt) }
      statement_by_receipt = statement_records.index_by { |record| record.fetch(:receipt) }

      {
        kind: kind,
        statement_only: statement_by_receipt.keys - local_by_receipt.keys,
        application_only: local_by_receipt.keys - statement_by_receipt.keys,
        amount_mismatches: (statement_by_receipt.keys & local_by_receipt.keys).filter_map do |receipt|
          local = local_by_receipt.fetch(receipt)
          statement = statement_by_receipt.fetch(receipt)
          { receipt: receipt, application_amount: local.fetch(:amount), statement_amount: statement.fetch(:amount) } if local.fetch(:amount) != statement.fetch(:amount)
        end
      }
    end

    private

    def read_statement(path)
      CSV.read(path, headers: true).map do |row|
        receipt = row["receipt"].to_s.strip
        decimal_amount = BigDecimal(row["amount"].to_s.delete(",").strip)
        raise ArgumentError if decimal_amount.frac.nonzero?
        amount = decimal_amount.to_i
        raise ArgumentError, "Statement rows require receipt and positive integer amount" if receipt.blank? || amount <= 0
        { receipt: receipt, amount: amount }
      rescue ArgumentError
        raise ArgumentError, "Statement must have receipt and positive integer amount columns"
      end
    end

    def c2b_records(start_time, end_time)
      MpesaPayment.where(received_at: start_time..end_time).find_each.map do |payment|
        { receipt: payment.mpesa_receipt, amount: payment.amount_kes }
      end
    end

    def b2c_records(start_time, end_time)
      MpesaPayout.where(status: "succeeded", succeeded_at: start_time..end_time).where.not(mpesa_receipt: nil).find_each.map do |payout|
        { receipt: payout.mpesa_receipt, amount: payout.amount_kes }
      end
    end
  end
end
