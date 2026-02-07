# frozen_string_literal: true

class CreateSimulatedOrders < ActiveRecord::Migration[8.0]
  def change
    create_table :simulated_orders, id: :uuid do |t|
      t.string :clover_order_id
      t.string :clover_merchant_id, null: false
      t.references :business_type, foreign_key: true, type: :uuid
      t.string :status, null: false, default: "open"
      t.integer :subtotal, default: 0       # cents
      t.integer :tax_amount, default: 0     # cents
      t.integer :tip_amount, default: 0     # cents
      t.integer :discount_amount, default: 0 # cents
      t.integer :total, default: 0          # cents
      t.string :dining_option
      t.string :meal_period
      t.jsonb :metadata, default: {}
      t.date :business_date, null: false

      t.timestamps
    end

    add_index :simulated_orders, :clover_order_id
    add_index :simulated_orders, :clover_merchant_id
    add_index :simulated_orders, :status
    add_index :simulated_orders, :business_date
    add_index :simulated_orders, :meal_period
    add_index :simulated_orders, :dining_option
    add_index :simulated_orders, :created_at
  end
end
