# frozen_string_literal: true

module CloverSandboxSimulator
  module Models
    class SimulatedOrder < Record
      belongs_to :business_type, optional: true
      has_many :simulated_payments, dependent: :destroy

      # Note: no has_many :items — simulated orders track monetary totals only.
      # Line-item detail lives in the Clover API response (stored in metadata jsonb).

      # Validations
      validates :clover_merchant_id, presence: true
      validates :status, presence: true
      validates :business_date, presence: true

      # Status scopes
      scope :successful, -> { where(status: "paid") }
      scope :open_orders, -> { where(status: "open") }
      scope :refunded, -> { where(status: "refunded") }

      # Time scopes
      scope :today, -> { where(business_date: Date.today) }
      scope :on_date, ->(date) { where(business_date: date) }
      scope :between_dates, ->(from, to) { where(business_date: from..to) }

      # Filter scopes
      scope :for_merchant, ->(merchant_id) { where(clover_merchant_id: merchant_id) }
      scope :for_meal_period, ->(period) { where(meal_period: period) }
      scope :for_dining_option, ->(option) { where(dining_option: option) }

      # Amounts in dollars (convenience)
      def total_dollars
        (total || 0) / 100.0
      end

      def subtotal_dollars
        (subtotal || 0) / 100.0
      end
    end
  end
end
