# frozen_string_literal: true

module CloverSandboxSimulator
  module Services
    module Clover
      # Manages Clover refunds for payments
      # Supports full and partial refunds with various refund reasons
      #
      # Refund strategies (in priority order):
      # 1. Ecommerce API (POST /v1/refunds) - for card payments created via Ecommerce API
      # 2. Voided line items - for non-card payments (Cash, Check, Gift Card)
      # 3. Platform API - if available (usually read-only in sandbox)
      # 4. Simulated refund - fallback for testing
      #
      # See: https://docs.clover.com/dev/reference/createrefund
      class RefundService < BaseService
        # Valid refund/void reasons (matching Clover's void reasons)
        REFUND_REASONS = %w[
          customer_request
          quality_issue
          wrong_order
          duplicate_charge
        ].freeze

        # Clover void reasons (from merchant settings)
        VOID_REASONS = [
          "Returned goods",
          "Accidental charge",
          "Fraudulent charge",
          "Customer complaint",
          "Order not correct",
          "Out of stock",
          "Damaged goods",
          "Goods not received"
        ].freeze

        # Map our refund reasons to Clover void reasons
        REASON_MAPPING = {
          "customer_request" => "Customer complaint",
          "quality_issue" => "Damaged goods",
          "wrong_order" => "Order not correct",
          "duplicate_charge" => "Accidental charge"
        }.freeze

        # Ecommerce refund reasons
        ECOMMERCE_REASONS = %w[
          requested_by_customer
          duplicate
          fraudulent
        ].freeze

        # Map our reasons to Ecommerce API reasons
        ECOMMERCE_REASON_MAPPING = {
          "customer_request" => "requested_by_customer",
          "quality_issue" => "requested_by_customer",
          "wrong_order" => "requested_by_customer",
          "duplicate_charge" => "duplicate"
        }.freeze

        def initialize(config: nil)
          super
          @ecommerce_service = nil
        end

        # Fetch all refunds for the merchant
        #
        # @param limit [Integer, nil] Maximum number of refunds to return
        # @param offset [Integer, nil] Offset for pagination
        # @return [Array<Hash>] Array of refund objects
        def fetch_refunds(limit: nil, offset: nil)
          logger.info "Fetching refunds..."

          params = {}
          params[:limit] = limit if limit
          params[:offset] = offset if offset

          response = request(:get, endpoint("refunds"), params: params.empty? ? nil : params)
          refunds = response&.dig("elements") || []

          logger.info "Found #{refunds.size} refunds"
          refunds
        end

        # Get a specific refund by ID
        #
        # @param refund_id [String] The refund ID
        # @return [Hash, nil] Refund object or nil if not found
        def get_refund(refund_id)
          logger.info "Fetching refund: #{refund_id}"

          response = request(:get, endpoint("refunds/#{refund_id}"))
          response
        end

        # Create a refund for a payment
        # Tries multiple strategies based on payment type and API availability
        #
        # @param payment_id [String] The payment ID to refund (Platform API) or charge ID (Ecommerce)
        # @param amount [Integer, nil] Refund amount in cents (nil for full refund)
        # @param reason [String] Reason for refund (default: customer_request)
        # @param charge_id [String, nil] Ecommerce charge ID (if known, uses Ecommerce API directly)
        # @return [Hash, nil] Refund response or nil on failure
        def create_refund(payment_id:, amount: nil, reason: "customer_request", charge_id: nil)
          unless REFUND_REASONS.include?(reason)
            logger.warn "Unknown refund reason '#{reason}', using 'customer_request'"
            reason = "customer_request"
          end

          if amount
            logger.info "Creating partial refund for payment #{payment_id}: $#{amount / 100.0} (#{reason})"
          else
            logger.info "Creating full refund for payment #{payment_id} (#{reason})"
          end

          # Try multiple approaches for sandbox compatibility
          response = try_ecommerce_refund(charge_id || payment_id, amount, reason) ||
                     try_void_line_items(payment_id, amount, reason) ||
                     try_platform_refund(payment_id, amount, reason) ||
                     simulate_refund(payment_id, amount, reason)

          if response && response["id"]
            logger.info "Refund successful: #{response["id"]} - $#{(response["amount"] || 0) / 100.0}"
          end

          response
        end

        # Create a refund for an Ecommerce charge (card payment)
        # This is the preferred method for card payments
        #
        # @param charge_id [String] The Ecommerce charge ID
        # @param amount [Integer, nil] Refund amount in cents (nil for full refund)
        # @param reason [String] Reason for refund
        # @return [Hash, nil] Refund response
        def create_ecommerce_refund(charge_id:, amount: nil, reason: "customer_request")
          ecommerce_reason = ECOMMERCE_REASON_MAPPING[reason] || "requested_by_customer"

          if amount
            logger.info "Creating Ecommerce partial refund for charge #{charge_id}: $#{amount / 100.0}"
          else
            logger.info "Creating Ecommerce full refund for charge #{charge_id}"
          end

          ecommerce_service.create_refund(
            charge_id: charge_id,
            amount: amount,
            reason: ecommerce_reason
          )
        end

        private

        # Get or create the Ecommerce service instance
        def ecommerce_service
          @ecommerce_service ||= EcommerceService.new(config: config)
        end

        # Attempt 0: Ecommerce API refund (for card payments)
        # Uses POST /v1/refunds with the charge ID
        def try_ecommerce_refund(charge_id, amount, reason)
          return nil unless config.ecommerce_enabled?

          ecommerce_reason = ECOMMERCE_REASON_MAPPING[reason] || "requested_by_customer"

          logger.debug "Trying Ecommerce API refund for #{charge_id}..."

          response = ecommerce_service.create_refund(
            charge_id: charge_id,
            amount: amount,
            reason: ecommerce_reason
          )

          if response && response["id"]
            logger.info "  ✓ Ecommerce refund created: #{response['id']}"
            response["type"] = "ecommerce_refund"
          end

          response
        rescue ApiError => e
          logger.debug "Ecommerce API refund not available: #{e.message}"
          nil
        end

        # Attempt 1: Void line items on the order (Platform API supported)
        # Uses DELETE /v3/merchants/{mId}/orders/{orderId}/line_items/{lineItemId}
        def try_void_line_items(payment_id, amount, reason)
          payment = get_payment(payment_id)
          return nil unless payment

          order_id = payment.dig("order", "id")
          return nil unless order_id

          # Get order with line items
          order = get_order_with_line_items(order_id)
          return nil unless order

          line_items = order.dig("lineItems", "elements") || []
          return nil if line_items.empty?

          void_reason = REASON_MAPPING[reason] || "Customer complaint"
          payment_amount = payment["amount"] || 0
          refund_amount = amount || payment_amount

          # For partial refund, void items until we reach the refund amount
          # For full refund, void all items
          voided_amount = 0
          voided_items = []

          items_to_void = if amount.nil?
                            line_items # Full refund - void all
                          else
                            # Partial refund - select items to void
                            select_items_for_amount(line_items, refund_amount)
                          end

          items_to_void.each do |item|
            item_id = item["id"]
            item_price = (item["price"] || 0) * (item["quantity"] || 1)

            begin
              # Void the line item
              void_result = void_line_item(order_id, item_id, void_reason)
              if void_result
                voided_items << item
                voided_amount += item_price
                logger.info "  ✓ Voided item: #{item.dig('name') || item_id} ($#{item_price / 100.0})"
              end
            rescue ApiError => e
              logger.debug "Could not void item #{item_id}: #{e.message}"
            end
          end

          return nil if voided_items.empty?

          # Return a refund-like response
          {
            "id" => "VOID_#{SecureRandom.hex(8).upcase}",
            "payment" => { "id" => payment_id },
            "order" => { "id" => order_id },
            "amount" => voided_amount,
            "reason" => void_reason,
            "voidedItems" => voided_items.map { |i| { "id" => i["id"], "name" => i["name"] } },
            "createdTime" => (Time.now.to_f * 1000).to_i,
            "type" => "voided_line_items"
          }
        rescue ApiError => e
          logger.debug "Void line items approach failed: #{e.message}"
          nil
        end

        # Void a single line item
        def void_line_item(order_id, line_item_id, reason = nil)
          # DELETE /v3/merchants/{mId}/orders/{orderId}/line_items/{lineItemId}
          params = reason ? { reason: reason } : nil
          request(:delete, endpoint("orders/#{order_id}/line_items/#{line_item_id}"), params: params)
          true
        rescue ApiError => e
          logger.debug "Could not void line item: #{e.message}"
          false
        end

        # Select line items to void that total approximately the refund amount
        def select_items_for_amount(line_items, target_amount)
          selected = []
          remaining = target_amount

          # Sort by price descending to minimize number of voids
          sorted_items = line_items.sort_by { |i| -(i["price"] || 0) }

          sorted_items.each do |item|
            break if remaining <= 0

            item_price = (item["price"] || 0) * (item["quantity"] || 1)
            if item_price <= remaining
              selected << item
              remaining -= item_price
            end
          end

          # If we couldn't match exactly, include at least one item
          selected << sorted_items.first if selected.empty? && sorted_items.any?

          selected
        end

        def get_order_with_line_items(order_id)
          request(:get, endpoint("orders/#{order_id}?expand=lineItems"))
        rescue ApiError => e
          logger.debug "Could not fetch order #{order_id}: #{e.message}"
          nil
        end

        # Attempt 2: Platform API refund endpoint (usually doesn't support POST)
        def try_platform_refund(payment_id, amount, reason)
          payload = {
            "payment" => { "id" => payment_id },
            "reason" => reason
          }
          payload["amount"] = amount if amount

          response = request(:post, endpoint("refunds"), payload: payload)
          response
        rescue ApiError => e
          logger.debug "Platform API refund not available: #{e.message}"
          nil
        end

        # Attempt 3: Simulate refund for sandbox testing (fallback)
        def simulate_refund(payment_id, amount, reason)
          logger.info "  📝 Simulating refund (sandbox fallback)"

          # Get payment details for simulation
          payment = get_payment(payment_id)
          refund_amount = amount || payment&.dig("amount") || 0

          # Return a simulated refund object
          {
            "id" => "SIM_#{SecureRandom.hex(8).upcase}",
            "payment" => { "id" => payment_id },
            "amount" => refund_amount,
            "reason" => reason,
            "createdTime" => (Time.now.to_f * 1000).to_i,
            "simulated" => true
          }
        end

        def get_payment(payment_id)
          request(:get, endpoint("payments/#{payment_id}"))
        rescue ApiError => e
          logger.debug "Could not fetch payment #{payment_id}: #{e.message}"
          nil
        end

        public

        # Create a full refund for a payment
        #
        # @param payment_id [String] The payment ID to refund
        # @param reason [String] Reason for refund
        # @return [Hash, nil] Refund response
        def create_full_refund(payment_id:, reason: "customer_request")
          create_refund(payment_id: payment_id, amount: nil, reason: reason)
        end

        # Create a partial refund for a payment
        #
        # @param payment_id [String] The payment ID to refund
        # @param amount [Integer] Refund amount in cents
        # @param reason [String] Reason for refund
        # @return [Hash, nil] Refund response
        def create_partial_refund(payment_id:, amount:, reason: "customer_request")
          raise ArgumentError, "Amount is required for partial refund" unless amount
          raise ArgumentError, "Amount must be positive" unless amount.positive?

          create_refund(payment_id: payment_id, amount: amount, reason: reason)
        end

        # Generate a random refund reason
        #
        # @return [String] Random refund reason
        def random_reason
          REFUND_REASONS.sample
        end
      end
    end
  end
end
