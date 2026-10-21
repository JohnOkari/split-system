class CreateMpesaSplitTables < ActiveRecord::Migration[7.2]
  def change
    create_table :mpesa_payments do |t|
      t.string :mpesa_receipt, null: false
      t.string :shortcode, null: false
      t.bigint :amount_kes, null: false
      t.string :bill_reference
      t.string :status, null: false, default: "received"
      t.datetime :received_at, null: false, default: -> { "CURRENT_TIMESTAMP" }
      t.timestamps
      t.index :mpesa_receipt, unique: true
      t.check_constraint "amount_kes > 0", name: "mpesa_payments_positive_amount"
    end

    create_table :split_allocations do |t|
      t.references :mpesa_payment, null: false, foreign_key: true, index: { unique: true }
      t.bigint :retained_kes, null: false
      t.bigint :recipient_kes, null: false
      t.timestamps
      t.check_constraint "retained_kes >= 0 AND recipient_kes >= 0", name: "split_allocations_nonnegative_shares"
    end

    create_table :mpesa_payouts do |t|
      t.references :split_allocation, null: false, foreign_key: true, index: { unique: true }
      t.string :recipient_phone, null: false
      t.bigint :amount_kes, null: false
      t.string :status, null: false, default: "pending"
      t.string :originator_conversation_id
      t.string :conversation_id
      t.string :mpesa_receipt
      t.string :result_code
      t.text :result_description
      t.integer :attempts, null: false, default: 0
      t.datetime :claimed_at
      t.datetime :succeeded_at
      t.timestamps
      t.index :originator_conversation_id, unique: true
      t.index :conversation_id
      t.index :mpesa_receipt, unique: true
      t.check_constraint "amount_kes > 0", name: "mpesa_payouts_positive_amount"
    end

    create_table :ledger_entries do |t|
      t.references :mpesa_payment, null: false, foreign_key: true
      t.string :account_code, null: false
      t.string :entry_type, null: false
      t.bigint :amount_kes, null: false
      t.string :event_key, null: false
      t.timestamps
      t.index :event_key, unique: true
      t.check_constraint "amount_kes > 0", name: "ledger_entries_positive_amount"
      t.check_constraint "entry_type IN ('debit', 'credit')", name: "ledger_entries_valid_entry_type"
    end

    create_table :mpesa_callback_events do |t|
      t.string :event_type, null: false
      t.string :deduplication_key, null: false
      t.jsonb :payload, null: false, default: {}
      t.string :processing_status, null: false, default: "received"
      t.text :processing_error
      t.datetime :processed_at
      t.timestamps
      t.index :deduplication_key, unique: true
    end

    create_table :mpesa_payout_attempts do |t|
      t.references :mpesa_payout, null: false, foreign_key: true
      t.string :originator_conversation_id, null: false
      t.string :status, null: false, default: "submitting"
      t.integer :http_status
      t.jsonb :response_body, null: false, default: {}
      t.text :error_message
      t.datetime :submitted_at
      t.timestamps
      t.index :originator_conversation_id, unique: true
    end

    create_table :mpesa_outbox_events do |t|
      t.string :event_type, null: false
      t.string :deduplication_key, null: false
      t.jsonb :payload, null: false, default: {}
      t.datetime :dispatched_at
      t.timestamps
      t.index :deduplication_key, unique: true
      t.index [:dispatched_at, :created_at]
    end
  end
end
