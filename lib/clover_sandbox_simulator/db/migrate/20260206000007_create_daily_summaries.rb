# frozen_string_literal: true

class CreateDailySummaries < ActiveRecord::Migration[8.0]
  def change
    create_table :daily_summaries, id: :uuid do |t|
      t.string :merchant_id, null: false
      t.date :business_date, null: false
      t.integer :order_count, default: 0
      t.integer :payment_count, default: 0
      t.integer :refund_count, default: 0
      t.integer :total_revenue, default: 0       # cents
      t.integer :total_tax, default: 0           # cents
      t.integer :total_tips, default: 0          # cents
      t.integer :total_discounts, default: 0     # cents
      t.jsonb :breakdown, default: {}

      t.timestamps
    end

    add_index :daily_summaries, [:merchant_id, :business_date], unique: true
    add_index :daily_summaries, :merchant_id
    add_index :daily_summaries, :business_date
  end
end
