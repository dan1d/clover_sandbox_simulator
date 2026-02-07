# frozen_string_literal: true

class CreateSimulatedOrders < ActiveRecord::Migration[8.0]
  def change
    create_table :simulated_orders, id: :uuid do |t|
      t.string :clover_order_id
      t.string :clover_merchant_id, null: false
      # Nullable: orders may be created before a business_type is assigned
      t.references :business_type, foreign_key: true, type: :uuid
      t.string :status, null: false, default: "open"
      t.integer :subtotal, default: 0        # cents
      t.integer :tax_amount, default: 0      # cents
      t.integer :tip_amount, default: 0      # cents
      t.integer :discount_amount, default: 0 # cents
      t.integer :total, default: 0           # cents
      t.string :dining_option
      t.string :meal_period
      t.jsonb :metadata, default: {}
      t.date :business_date, null: false

      t.timestamps
    end

    # Unique per merchant — prevents duplicate inserts on retry
    add_index :simulated_orders, [:clover_merchant_id, :clover_order_id],
              unique: true,
              where: "clover_order_id IS NOT NULL",
              name: "idx_simulated_orders_merchant_clover_unique"
    add_index :simulated_orders, :clover_merchant_id
    add_index :simulated_orders, :status
    add_index :simulated_orders, :business_date
    add_index :simulated_orders, :meal_period
    add_index :simulated_orders, :dining_option
    add_index :simulated_orders, :created_at
  end
end
