# frozen_string_literal: true

module CloverSandboxSimulator
  module Models
    class ApiRequest < Record
      # Validations
      validates :http_method, presence: true
      validates :url, presence: true

      # Time scopes — use Time.now.utc for consistency with AR's UTC storage
      scope :today, -> { where("created_at >= ?", Time.now.utc.beginning_of_day) }
      scope :recent, ->(minutes = 60) { where("created_at >= ?", minutes.minutes.ago) }

      # Status scopes
      scope :errors, -> { where("response_status >= 400 OR error_message IS NOT NULL") }
      scope :successful, -> { where("response_status < 400 AND error_message IS NULL") }

      # Resource scopes
      scope :for_resource, ->(type) { where(resource_type: type) }
      scope :for_resource_id, ->(type, id) { where(resource_type: type, resource_id: id) }

      # Merchant scope — matches /merchants/<id>/ or /merchants/<id> (end of URL)
      scope :for_merchant, ->(merchant_id) {
        sanitized = sanitize_sql_like(merchant_id)
        where("url LIKE ?", "%/merchants/#{sanitized}/%")
          .or(where("url LIKE ?", "%/merchants/#{sanitized}"))
      }

      # HTTP method scopes
      scope :gets, -> { where(http_method: "GET") }
      scope :posts, -> { where(http_method: "POST") }
      scope :puts, -> { where(http_method: "PUT") }
      scope :deletes, -> { where(http_method: "DELETE") }

      # Performance
      scope :slow, ->(threshold_ms = 1000) { where("duration_ms > ?", threshold_ms) }

      def error?
        error_message.present? || (response_status && response_status >= 400)
      end
    end
  end
end
