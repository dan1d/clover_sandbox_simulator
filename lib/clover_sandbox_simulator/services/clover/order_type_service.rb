# frozen_string_literal: true

module CloverSandboxSimulator
  module Services
    module Clover
      # Manages Clover order types (Dine In, Takeout, Delivery, etc.)
      class OrderTypeService < BaseService
        # Default order types that restaurants typically have
        DEFAULT_ORDER_TYPES = [
          { taxable: true, isDefault: false, filterCategories: false, isHidden: false, fee: 0, minOrderAmount: 0, maxOrderAmount: nil, maxRadius: nil, avgOrderTime: 0, hoursAvailable: "BUSINESS", isDeleted: false, label: "Dine In" },
          { taxable: true, isDefault: false, filterCategories: false, isHidden: false, fee: 0, minOrderAmount: 0, maxOrderAmount: nil, maxRadius: nil, avgOrderTime: 15, hoursAvailable: "BUSINESS", isDeleted: false, label: "Takeout" },
          { taxable: true, isDefault: false, filterCategories: false, isHidden: false, fee: 200, minOrderAmount: 1500, maxOrderAmount: nil, maxRadius: 5, avgOrderTime: 45, hoursAvailable: "BUSINESS", isDeleted: false, label: "Delivery" },
          { taxable: true, isDefault: false, filterCategories: false, isHidden: false, fee: 0, minOrderAmount: 0, maxOrderAmount: nil, maxRadius: nil, avgOrderTime: 10, hoursAvailable: "BUSINESS", isDeleted: false, label: "Curbside Pickup" },
          { taxable: true, isDefault: false, filterCategories: false, isHidden: false, fee: 0, minOrderAmount: 5000, maxOrderAmount: nil, maxRadius: nil, avgOrderTime: 0, hoursAvailable: "BUSINESS", isDeleted: false, label: "Catering" }
        ].freeze

        # Fetch all order types for the merchant
        def get_order_types
          logger.info "Fetching order types..."
          response = request(:get, endpoint("order_types"))
          types = response&.dig("elements") || []
          logger.info "Found #{types.size} order types"
          types
        end

        # Create a new order type
        # @param label [String] The display name
        # @param taxable [Boolean] Whether orders of this type are taxable
        # @param fee [Integer] Delivery/service fee in cents
        # @param min_order_amount [Integer] Minimum order amount in cents
        # @param avg_order_time [Integer] Average order time in minutes
        def create_order_type(label:, taxable: true, fee: 0, min_order_amount: 0, avg_order_time: 0)
          logger.info "Creating order type: #{label}"

          payload = {
            "label" => label,
            "taxable" => taxable,
            "fee" => fee,
            "minOrderAmount" => min_order_amount,
            "avgOrderTime" => avg_order_time,
            "isDeleted" => false
          }

          request(:post, endpoint("order_types"), payload: payload)
        end

        # Set order type for an order
        # @param order_id [String] The order ID
        # @param order_type_id [String] The order type ID
        def set_order_type(order_id, order_type_id)
          logger.debug "Setting order type #{order_type_id} for order #{order_id}"

          request(:post, endpoint("orders/#{order_id}"), payload: {
            "orderType" => { "id" => order_type_id }
          })
        end

        # Setup default order types if they don't exist
        def setup_default_order_types
          existing = get_order_types
          existing_labels = existing.map { |t| t["label"]&.downcase }

          created = []
          DEFAULT_ORDER_TYPES.each do |type_data|
            if existing_labels.include?(type_data[:label].downcase)
              logger.debug "Order type '#{type_data[:label]}' already exists"
              created << existing.find { |t| t["label"]&.downcase == type_data[:label].downcase }
            else
              result = create_order_type(
                label: type_data[:label],
                taxable: type_data[:taxable],
                fee: type_data[:fee],
                min_order_amount: type_data[:minOrderAmount],
                avg_order_time: type_data[:avgOrderTime]
              )
              created << result if result
            end
          end

          logger.info "Order types ready: #{created.size}"
          created
        end
      end
    end
  end
end
