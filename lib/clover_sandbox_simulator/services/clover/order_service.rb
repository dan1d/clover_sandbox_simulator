# frozen_string_literal: true

module CloverSandboxSimulator
  module Services
    module Clover
      # Manages Clover orders and line items
      class OrderService < BaseService
        DINING_OPTIONS = %w[HERE TO_GO DELIVERY].freeze

        # Fetch all orders
        def get_orders(limit: 50, offset: 0, filter: nil)
          logger.info "Fetching orders..."
          params = { limit: limit, offset: offset }
          params[:filter] = filter if filter

          response = request(:get, endpoint("orders"), params: params)
          response&.dig("elements") || []
        end

        # Get a single order with expanded data
        def get_order(order_id)
          request(:get, endpoint("orders/#{order_id}"), params: {
            expand: "lineItems,discounts,payments,customers"
          })
        end

        # Create an order shell
        def create_order(employee_id: nil, customer_id: nil)
          logger.info "Creating order..."

          payload = {}
          payload["employee"] = { "id" => employee_id } if employee_id

          order = request(:post, endpoint("orders"), payload: payload)

          if order && customer_id
            add_customer_to_order(order["id"], customer_id)
          end

          order
        end

        # Add line item to order
        def add_line_item(order_id, item_id:, quantity: 1, note: nil)
          logger.debug "Adding item #{item_id} to order #{order_id}"

          payload = {
            "item" => { "id" => item_id },
            "quantity" => quantity
          }
          payload["note"] = note if note

          request(:post, endpoint("orders/#{order_id}/line_items"), payload: payload)
        end

        # Batch add line items (adds one by one as Clover doesn't support bulk)
        # @param order_id [String] The order ID to add items to
        # @param items [Array<Hash>] Array of items with :item_id, :quantity, :note
        # @param raise_on_empty [Boolean] If true, raises an error when no items are added
        # @return [Array] Successfully added line items
        def add_line_items(order_id, items, raise_on_empty: false)
          logger.info "Adding #{items.size} items to order #{order_id}"

          line_items = []
          failed_count = 0

          items.each do |item|
            line_item = add_line_item(
              order_id,
              item_id: item[:item_id],
              quantity: item[:quantity] || 1,
              note: item[:note]
            )

            if line_item
              line_items << line_item
            else
              failed_count += 1
              logger.debug "Failed to add item #{item[:item_id]} to order #{order_id}"
            end
          end

          if line_items.empty? && items.any?
            message = "All #{items.size} line items failed to be added to order #{order_id}"
            logger.warn message
            raise StandardError, message if raise_on_empty
          elsif failed_count > 0
            logger.warn "#{failed_count} of #{items.size} line items failed to be added to order #{order_id}"
          end

          line_items
        end

        # Apply discount to order
        # IMPORTANT: Always sends calculated amount, not percentage, so that
        # the discount amount is correctly returned when fetching the order.
        def apply_discount(order_id, discount_id:, calculated_amount: nil)
          logger.info "Applying discount #{discount_id} to order #{order_id}"

          # Fetch discount details
          discount_service = DiscountService.new(config: config)
          discount = discount_service.get_discount(discount_id)

          return nil unless discount

          payload = { "name" => discount["name"] }

          if calculated_amount
            payload["amount"] = -calculated_amount.abs
          elsif discount["amount"]
            payload["amount"] = discount["amount"]
          elsif discount["percentage"]
            # For percentage discounts, we MUST calculate the amount
            # because Clover returns amount=0 for percentage discounts when fetched
            order_total = calculate_total(order_id)
            calculated = (order_total * discount["percentage"] / 100.0).round
            logger.info "Calculated discount: #{discount["percentage"]}% of #{order_total} = #{calculated}"
            payload["amount"] = -calculated.abs
          end

          request(:post, endpoint("orders/#{order_id}/discounts"), payload: payload)
        end

        # Apply an inline discount without requiring a pre-existing discount ID
        # IMPORTANT: For percentage discounts, caller should provide the order_total
        # so we can calculate the actual amount. Otherwise Clover returns amount=0.
        def apply_inline_discount(order_id, name:, percentage: nil, amount: nil, order_total: nil)
          logger.info "Applying inline discount '#{name}' to order #{order_id}"

          payload = { "name" => name }

          if amount
            payload["amount"] = -amount.abs
          elsif percentage
            # Calculate the actual amount for percentage discounts
            if order_total
              calculated = (order_total * percentage / 100.0).round
              logger.info "Calculated inline discount: #{percentage}% of #{order_total} = #{calculated}"
              payload["amount"] = -calculated.abs
            else
              # Fallback: fetch order total and calculate
              total = calculate_total(order_id)
              calculated = (total * percentage / 100.0).round
              logger.info "Calculated inline discount: #{percentage}% of #{total} = #{calculated}"
              payload["amount"] = -calculated.abs
            end
          else
            raise ArgumentError, "Must provide either percentage or amount"
          end

          request(:post, endpoint("orders/#{order_id}/discounts"), payload: payload)
        end

        # Set dining option
        def set_dining_option(order_id, option)
          unless DINING_OPTIONS.include?(option)
            raise ArgumentError, "Invalid dining option: #{option}. Must be one of #{DINING_OPTIONS.join(', ')}"
          end

          request(:post, endpoint("orders/#{order_id}"), payload: { "diningOption" => option })
        end

        # Add customer to order
        def add_customer_to_order(order_id, customer_id)
          logger.debug "Adding customer #{customer_id} to order #{order_id}"
          request(:post, endpoint("orders/#{order_id}"), payload: {
            "customers" => { "elements" => [{ "id" => customer_id }] }
          })
        end

        # Update order total
        def update_total(order_id, total)
          logger.debug "Updating order #{order_id} total to #{total}"
          request(:post, endpoint("orders/#{order_id}"), payload: { "total" => total })
        end

        # Update order state
        def update_state(order_id, state)
          logger.info "Updating order #{order_id} state to #{state}"
          request(:post, endpoint("orders/#{order_id}"), payload: { "state" => state })
        end

        # Calculate order total from line items
        def calculate_total(order_id)
          order = get_order(order_id)
          return 0 unless order && order["lineItems"]&.dig("elements")

          total = 0

          order["lineItems"]["elements"].each do |line_item|
            price = line_item["price"] || 0
            quantity = line_item["quantity"] || 1
            item_total = price * quantity

            # Add modification prices
            if line_item["modifications"]&.dig("elements")
              line_item["modifications"]["elements"].each do |mod|
                item_total += (mod["price"] || 0)
              end
            end

            total += item_total
          end

          # Subtract discounts
          if order["discounts"]&.dig("elements")
            order["discounts"]["elements"].each do |discount|
              if discount["percentage"]
                total -= (total * discount["percentage"] / 100.0).round
              else
                total -= (discount["amount"] || 0).abs
              end
            end
          end

          total
        end

        # Delete an order
        def delete_order(order_id)
          logger.info "Deleting order: #{order_id}"
          request(:delete, endpoint("orders/#{order_id}"))
        end
      end
    end
  end
end
