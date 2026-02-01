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
        def add_line_items(order_id, items)
          logger.info "Adding #{items.size} items to order #{order_id}"

          line_items = []
          items.each do |item|
            line_item = add_line_item(
              order_id,
              item_id: item[:item_id],
              quantity: item[:quantity] || 1,
              note: item[:note]
            )
            line_items << line_item if line_item
          end

          line_items
        end

        # Apply discount to order
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
            payload["percentage"] = discount["percentage"].to_s
          end

          request(:post, endpoint("orders/#{order_id}/discounts"), payload: payload)
        end

        # Apply an inline discount without requiring a pre-existing discount ID
        def apply_inline_discount(order_id, name:, percentage: nil, amount: nil)
          logger.info "Applying inline discount '#{name}' to order #{order_id}"

          payload = { "name" => name }

          if percentage
            payload["percentage"] = percentage.to_s
          elsif amount
            payload["amount"] = -amount.abs
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
