# frozen_string_literal: true

module CloverSandboxSimulator
  module Services
    module Clover
      # Manages Clover refunds for payments
      # Supports full and partial refunds with various refund reasons
      class RefundService < BaseService
        # Valid refund reasons
        REFUND_REASONS = %w[
          customer_request
          quality_issue
          wrong_order
          duplicate_charge
        ].freeze

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
        #
        # @param payment_id [String] The payment ID to refund
        # @param amount [Integer, nil] Refund amount in cents (nil for full refund)
        # @param reason [String] Reason for refund (default: customer_request)
        # @return [Hash, nil] Refund response or nil on failure
        def create_refund(payment_id:, amount: nil, reason: "customer_request")
          unless REFUND_REASONS.include?(reason)
            logger.warn "Unknown refund reason '#{reason}', using 'customer_request'"
            reason = "customer_request"
          end

          if amount
            logger.info "Creating partial refund for payment #{payment_id}: $#{amount / 100.0} (#{reason})"
          else
            logger.info "Creating full refund for payment #{payment_id} (#{reason})"
          end

          payload = {
            "payment" => { "id" => payment_id },
            "reason" => reason
          }

          # Only include amount for partial refunds
          payload["amount"] = amount if amount

          response = request(:post, endpoint("refunds"), payload: payload)

          if response && response["id"]
            logger.info "Refund successful: #{response["id"]} - $#{(response["amount"] || 0) / 100.0}"
          else
            logger.error "Refund failed: #{response.inspect}"
          end

          response
        end

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
