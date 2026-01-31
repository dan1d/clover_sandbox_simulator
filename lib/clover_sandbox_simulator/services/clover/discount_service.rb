# frozen_string_literal: true

module CloverSandboxSimulator
  module Services
    module Clover
      # Manages Clover discounts
      class DiscountService < BaseService
        # Fetch all discounts
        def get_discounts
          logger.info "Fetching discounts..."
          response = request(:get, endpoint("discounts"))
          elements = response&.dig("elements") || []
          logger.info "Found #{elements.size} discounts"
          elements
        end

        # Get a specific discount
        def get_discount(discount_id)
          request(:get, endpoint("discounts/#{discount_id}"))
        end

        # Create a fixed amount discount
        def create_fixed_discount(name:, amount:)
          logger.info "Creating fixed discount: #{name} ($#{amount / 100.0})"

          request(:post, endpoint("discounts"), payload: {
            "name" => name,
            "amount" => -amount.abs # Clover expects negative for discounts
          })
        end

        # Create a percentage discount
        def create_percentage_discount(name:, percentage:)
          logger.info "Creating percentage discount: #{name} (#{percentage}%)"

          request(:post, endpoint("discounts"), payload: {
            "name" => name,
            "percentage" => percentage
          })
        end

        # Delete a discount
        def delete_discount(discount_id)
          logger.info "Deleting discount: #{discount_id}"
          request(:delete, endpoint("discounts/#{discount_id}"))
        end

        # Select a random discount (30% chance of returning nil)
        def random_discount
          return nil if rand < 0.7 # 70% chance of no discount

          discounts = get_discounts
          discounts.sample
        end
      end
    end
  end
end
