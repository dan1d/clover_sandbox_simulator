# frozen_string_literal: true

class CreateSimulatedPayments < ActiveRecord::Migration[8.0]
  def change
    create_table :simulated_payments, id: :uuid do |t|
      t.references :simulated_order, null: false, foreign_key: true, type: :uuid
      t.string :clover_payment_id
      t.string :tender_name, null: false
      t.integer :amount, default: 0      # cents
      t.integer :tip_amount, default: 0  # cents
      t.integer :tax_amount, default: 0  # cents
      t.string :status, null: false, default: "pending"
      t.string :payment_type

      t.timestamps
    end

    add_index :simulated_payments, :clover_payment_id
    add_index :simulated_payments, :tender_name
    add_index :simulated_payments, :status
    add_index :simulated_payments, :created_at
  end
end
