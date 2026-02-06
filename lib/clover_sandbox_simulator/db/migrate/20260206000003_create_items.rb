# frozen_string_literal: true

class CreateItems < ActiveRecord::Migration[8.0]
  def change
    create_table :items, id: :uuid do |t|
      t.references :category, null: false, foreign_key: true, type: :uuid
      t.string :name, null: false
      t.integer :price, null: false  # stored in cents
      t.string :sku
      t.string :unit
      t.boolean :active, default: true, null: false
      t.jsonb :variants, default: []
      t.jsonb :metadata, default: {}

      t.timestamps
    end

    add_index :items, [:category_id, :name], unique: true
    add_index :items, :sku
    add_index :items, :active
  end
end
