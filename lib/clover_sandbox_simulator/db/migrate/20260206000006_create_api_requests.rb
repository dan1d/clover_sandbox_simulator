# frozen_string_literal: true

class CreateApiRequests < ActiveRecord::Migration[8.0]
  def change
    create_table :api_requests, id: :uuid do |t|
      t.string :http_method, null: false
      t.text :url, null: false
      t.jsonb :request_payload, default: {}
      t.jsonb :response_payload, default: {}
      t.integer :response_status
      t.integer :duration_ms
      t.text :error_message
      t.string :resource_type
      t.string :resource_id

      t.timestamps
    end

    add_index :api_requests, :http_method
    add_index :api_requests, :resource_id
    add_index :api_requests, [:resource_type, :resource_id]
    add_index :api_requests, :created_at
    add_index :api_requests, :response_status
  end
end
