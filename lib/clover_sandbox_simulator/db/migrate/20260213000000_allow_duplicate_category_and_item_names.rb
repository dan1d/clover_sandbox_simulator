# frozen_string_literal: true

class AllowDuplicateCategoryAndItemNames < ActiveRecord::Migration[8.0]
  def change
    remove_index :categories, [:business_type_id, :name], if_exists: true
    add_index :categories, [:business_type_id, :name], name: "index_categories_on_business_type_id_and_name"

    remove_index :items, [:category_id, :name], if_exists: true
    add_index :items, [:category_id, :name], name: "index_items_on_category_id_and_name"
  end
end
