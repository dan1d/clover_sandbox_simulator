# frozen_string_literal: true

module CloverSandboxSimulator
  module Services
    module Clover
      # Manages Clover cash events (drawer operations, cash tracking)
      class CashEventService < BaseService
        # Cash event types
        EVENT_TYPES = %w[OPEN CLOSE ADD REMOVE PAY REFUND].freeze

        # Fetch cash events
        def get_cash_events(limit: 100)
          logger.info "Fetching cash events..."
          response = request(:get, endpoint("cash_events"), params: { limit: limit })
          events = response&.dig("elements") || []
          logger.info "Found #{events.size} cash events"
          events
        end

      # Create a cash event
      # @param type [String] Event type (OPEN, CLOSE, ADD, REMOVE, PAY, REFUND)
      # @param amount [Integer] Amount in cents
      # @param employee_id [String] Employee ID
      # @param note [String, nil] Optional note
      # @note This may not work in sandbox environments where POST is not allowed
      def create_cash_event(type:, amount:, employee_id:, note: nil)
        unless EVENT_TYPES.include?(type.upcase)
          raise ArgumentError, "Invalid cash event type: #{type}. Must be one of: #{EVENT_TYPES.join(', ')}"
        end

        logger.info "Creating cash event: #{type} for $#{'%.2f' % (amount / 100.0)}"

        payload = {
          "type" => type.upcase,
          "amountChange" => amount,
          "employee" => { "id" => employee_id },
          "timestamp" => (Time.now.to_f * 1000).to_i
        }
        payload["note"] = note if note

        begin
          request(:post, endpoint("cash_events"), payload: payload)
        rescue ApiError => e
          if e.message.include?("405")
            logger.warn "Cash event creation not supported in this environment (405 Method Not Allowed)"
            logger.warn "Cash events may need to be created through the Clover device/dashboard"
            # Return a simulated response for tracking purposes
            { "type" => type.upcase, "amountChange" => amount, "simulated" => true }
          else
            raise
          end
        end
      end

        # Open cash drawer (start of shift/day)
        # @param employee_id [String] Employee ID
        # @param starting_cash [Integer] Starting cash amount in cents
        def open_drawer(employee_id:, starting_cash: 20000) # Default $200 starting cash
          logger.info "Opening cash drawer with $#{'%.2f' % (starting_cash / 100.0)}"
          create_cash_event(type: "OPEN", amount: starting_cash, employee_id: employee_id, note: "Drawer opened")
        end

        # Close cash drawer (end of shift/day)
        # @param employee_id [String] Employee ID
        # @param final_amount [Integer] Final cash amount in cents
        def close_drawer(employee_id:, final_amount:)
          logger.info "Closing cash drawer with $#{'%.2f' % (final_amount / 100.0)}"
          create_cash_event(type: "CLOSE", amount: final_amount, employee_id: employee_id, note: "Drawer closed")
        end

        # Add cash to drawer (cash drop/deposit)
        # @param employee_id [String] Employee ID
        # @param amount [Integer] Amount in cents
        # @param note [String, nil] Reason for adding cash
        def add_cash(employee_id:, amount:, note: nil)
          logger.info "Adding $#{'%.2f' % (amount / 100.0)} to drawer"
          create_cash_event(type: "ADD", amount: amount, employee_id: employee_id, note: note || "Cash added")
        end

        # Remove cash from drawer (paid out, deposit)
        # @param employee_id [String] Employee ID
        # @param amount [Integer] Amount in cents
        # @param note [String, nil] Reason for removing cash
        def remove_cash(employee_id:, amount:, note: nil)
          logger.info "Removing $#{'%.2f' % (amount / 100.0)} from drawer"
          create_cash_event(type: "REMOVE", amount: -amount.abs, employee_id: employee_id, note: note || "Cash removed")
        end

        # Record a cash payment received
        # @param employee_id [String] Employee ID
        # @param amount [Integer] Payment amount in cents
        def record_cash_payment(employee_id:, amount:)
          create_cash_event(type: "PAY", amount: amount, employee_id: employee_id)
        end

        # Record a cash refund given
        # @param employee_id [String] Employee ID
        # @param amount [Integer] Refund amount in cents
        def record_cash_refund(employee_id:, amount:)
          create_cash_event(type: "REFUND", amount: -amount.abs, employee_id: employee_id)
        end

        # Calculate expected drawer total from events
        def calculate_drawer_total(events = nil)
          events ||= get_cash_events
          events.sum { |e| e["amountChange"] || 0 }
        end
      end
    end
  end
end
