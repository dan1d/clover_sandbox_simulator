# frozen_string_literal: true

module CloverSandboxSimulator
  module Models
    class DailySummary < Record
      # Validations
      validates :merchant_id, presence: true
      validates :business_date, presence: true,
                                uniqueness: { scope: :merchant_id }

      # Scopes
      scope :for_merchant, ->(merchant_id) { where(merchant_id: merchant_id) }
      scope :on_date, ->(date) { where(business_date: date) }
      scope :today, -> { where(business_date: Date.today) }
      scope :between_dates, ->(from, to) { where(business_date: from..to) }
      scope :recent, ->(days = 7) { where("business_date >= ?", days.days.ago.to_date) }

      # Generate (or update) a daily summary by aggregating simulated orders.
      # Race-condition safe: retries on unique constraint violation.
      #
      # @param merchant_id [String] Clover merchant ID
      # @param date [Date] Business date to summarize
      # @return [DailySummary] the created or updated summary
      def self.generate_for!(merchant_id, date)
        orders = SimulatedOrder.for_merchant(merchant_id).on_date(date).successful
        payments = SimulatedPayment.joins(:simulated_order)
                                   .where(simulated_orders: {
                                     clover_merchant_id: merchant_id,
                                     business_date: date,
                                     status: "paid"
                                   })

        # Build breakdown by meal period and dining option
        breakdown = {
          by_meal_period: orders.group(:meal_period).count,
          by_dining_option: orders.group(:dining_option).count,
          by_tender: payments.group(:tender_name).count,
          revenue_by_meal_period: orders.group(:meal_period).sum(:total),
          revenue_by_dining_option: orders.group(:dining_option).sum(:total)
        }

        attrs = {
          order_count: orders.count,
          payment_count: payments.count,
          refund_count: SimulatedOrder.for_merchant(merchant_id).on_date(date).refunded.count,
          total_revenue: orders.sum(:total),
          total_tax: orders.sum(:tax_amount),
          total_tips: orders.sum(:tip_amount),
          total_discounts: orders.sum(:discount_amount),
          breakdown: breakdown
        }

        summary = find_or_initialize_by(merchant_id: merchant_id, business_date: date)
        summary.assign_attributes(attrs)
        summary.save!
        summary
      rescue ::ActiveRecord::RecordNotUnique
        # Concurrent insert won — retry will find the existing record and update it
        retry
      end

      # Convenience: total revenue in dollars
      def total_revenue_dollars
        (total_revenue || 0) / 100.0
      end
    end
  end
end
