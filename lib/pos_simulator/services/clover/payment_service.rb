# frozen_string_literal: true

module PosSimulator
  module Services
    module Clover
      # Manages Clover payments
      # NOTE: Credit/Debit card payments are BROKEN in Clover sandbox
      # Use Cash, Check, Gift Card, External Payment, Store Credit instead
      class PaymentService < BaseService
        # Fetch all payments
        def get_payments
          logger.info "Fetching payments..."
          response = request(:get, endpoint("payments"))
          response&.dig("elements") || []
        end

        # Process a payment for an order
        #
        # @param order_id [String] The order ID
        # @param amount [Integer] Subtotal amount in cents (before tip/tax)
        # @param tender_id [String] The tender ID to use
        # @param employee_id [String] The employee processing payment
        # @param tip_amount [Integer] Tip amount in cents
        # @param tax_amount [Integer] Tax amount in cents
        # @return [Hash, nil] Payment response or nil on failure
        def process_payment(order_id:, amount:, tender_id:, employee_id:, tip_amount: 0, tax_amount: 0)
          logger.info "Processing payment for order #{order_id}: $#{amount / 100.0} + tip $#{tip_amount / 100.0} + tax $#{tax_amount / 100.0}"

          payload = {
            "order" => { "id" => order_id },
            "tender" => { "id" => tender_id },
            "employee" => { "id" => employee_id },
            "offline" => false,
            "amount" => amount,
            "tipAmount" => tip_amount,
            "taxAmount" => tax_amount,
            "transactionSettings" => {
              "disableCashBack" => false,
              "cloverShouldHandleReceipts" => true,
              "forcePinEntryOnSwipe" => false,
              "disableRestartTransactionOnFailure" => false,
              "allowOfflinePayment" => false,
              "approveOfflinePaymentWithoutPrompt" => false,
              "forceOfflinePayment" => false,
              "disableReceiptSelection" => false,
              "disableDuplicateCheck" => false,
              "autoAcceptPaymentConfirmations" => false,
              "autoAcceptSignature" => false,
              "returnResultOnTransactionComplete" => false,
              "disableCreditSurcharge" => false
            }
          }

          response = request(:post, endpoint("orders/#{order_id}/payments"), payload: payload)

          if response && response["id"]
            logger.info "Payment successful: #{response["id"]}"
          else
            logger.error "Payment failed: #{response.inspect}"
          end

          response
        end

        # Process split payment across multiple tenders
        #
        # @param order_id [String] The order ID
        # @param total_amount [Integer] Total amount including tax (before tip)
        # @param tip_amount [Integer] Total tip amount
        # @param tax_amount [Integer] Tax amount
        # @param employee_id [String] Employee ID
        # @param splits [Array<Hash>] Array of { tender:, percentage: } hashes
        # @return [Array<Hash>] Array of payment responses
        def process_split_payment(order_id:, total_amount:, tip_amount:, tax_amount:, employee_id:, splits:)
          logger.info "Processing split payment for order #{order_id} across #{splits.size} tenders"

          payments = []
          remaining_amount = total_amount
          remaining_tip = tip_amount

          splits.each_with_index do |split, index|
            tender = split[:tender]
            percentage = split[:percentage]
            is_last = (index == splits.size - 1)

            # Calculate this payment's portion
            if is_last
              payment_amount = remaining_amount
              payment_tip = remaining_tip
            else
              payment_amount = (total_amount * percentage / 100.0).round
              payment_tip = (tip_amount * percentage / 100.0).round
              remaining_amount -= payment_amount
              remaining_tip -= payment_tip
            end

            # Tax only on first payment
            payment_tax = index.zero? ? tax_amount : 0

            payment = process_payment(
              order_id: order_id,
              amount: payment_amount,
              tender_id: tender["id"],
              employee_id: employee_id,
              tip_amount: payment_tip,
              tax_amount: payment_tax
            )

            payments << payment if payment
          end

          payments
        end

        # Generate a random tip amount (15-25% of subtotal)
        def generate_tip(subtotal)
          tip_percentage = rand(15..25)
          (subtotal * tip_percentage / 100.0).round
        end
      end
    end
  end
end
