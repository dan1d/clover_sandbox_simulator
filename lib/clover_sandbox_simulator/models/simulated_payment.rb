# frozen_string_literal: true

module CloverSandboxSimulator
  module Models
    class SimulatedPayment < Record
      belongs_to :simulated_order

      # Validations
      validates :tender_name, presence: true
      validates :status, presence: true
      validates :amount, numericality: { only_integer: true }

      # Status scopes
      scope :successful, -> { where(status: "paid") }
      scope :pending, -> { where(status: "pending") }
      scope :refunded, -> { where(status: "refunded") }

      # Tender scopes
      scope :cash, -> { where(tender_name: "Cash") }
      scope :by_tender, ->(name) { where(tender_name: name) }

      # Amount in dollars (convenience)
      def amount_dollars
        amount / 100.0
      end
    end
  end
end
