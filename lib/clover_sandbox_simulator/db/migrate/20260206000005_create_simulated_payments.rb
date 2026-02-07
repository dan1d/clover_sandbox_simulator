# frozen_string_literal: true

class CreateSimulatedPayments < ActiveRecord::Migration[8.0]
  def change
    create_table :simulated_payments, id: :uuid do |t|
      t.references :simulated_order, null: false, foreign_key: { on_delete: :cascade }, type: :uuid
      t.string :clover_payment_id
      t.string :tender_name, null: false
      t.integer :amount, default: 0      # cents
      t.integer :tip_amount, default: 0  # cents
      t.integer :tax_amount, default: 0  # cents
      t.string :status, null: false, default: "pending"
      t.string :payment_type

      t.timestamps
    end

    # Unique — prevents duplicate payment inserts on retry
    add_index :simulated_payments, :clover_payment_id,
              unique: true,
              where: "clover_payment_id IS NOT NULL"
    add_index :simulated_payments, :tender_name
    add_index :simulated_payments, :status
    add_index :simulated_payments, :created_at
  end
end
