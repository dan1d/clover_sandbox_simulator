# frozen_string_literal: true

class CreateCategories < ActiveRecord::Migration[8.0]
  def change
    create_table :categories, id: :uuid do |t|
      t.references :business_type, null: false, foreign_key: { on_delete: :cascade }, type: :uuid
      t.string :name, null: false
      t.integer :sort_order, default: 0
      t.text :description
      t.string :tax_group

      t.timestamps
    end

    add_index :categories, [:business_type_id, :name], unique: true
    add_index :categories, :sort_order
  end
end
