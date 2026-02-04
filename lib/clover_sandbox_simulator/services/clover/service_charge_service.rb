# frozen_string_literal: true

module CloverSandboxSimulator
  module Services
    module Clover
      # Manages Clover service charges (auto-gratuity, large party fees, etc.)
      class ServiceChargeService < BaseService
        AUTO_GRATUITY_NAME = "Auto Gratuity"
        DEFAULT_AUTO_GRATUITY_PERCENTAGE = 18.0

        # Fetch all service charges for the merchant
        def get_service_charges
          logger.info "Fetching service charges..."
          response = request(:get, endpoint("default_service_charge"))
          charges = response&.dig("elements") || []
          logger.info "Found #{charges.size} service charges"
          charges
        end

        # Create a new service charge
        # NOTE: In sandbox, service charges must be created via the Clover dashboard
        # This method attempts the API call but gracefully handles failures
        # @param name [String] The name of the service charge
        # @param percentage [Float] The percentage (e.g., 18.0 for 18%)
        # @param enabled [Boolean] Whether the charge is enabled
        def create_service_charge(name:, percentage:, enabled: true)
          logger.info "Creating service charge: #{name} (#{percentage}%)"

          # Clover uses percentageDecimal which is percentage * 100 (e.g., 18% = 1800)
          percentage_decimal = (percentage * 100).to_i

          payload = {
            "name" => name,
            "percentageDecimal" => percentage_decimal,
            "enabled" => enabled
          }

          begin
            request(:post, endpoint("default_service_charge"), payload: payload)
          rescue ApiError => e
            # Sandbox may not support POST to default_service_charge
            logger.warn "Could not create service charge via API: #{e.message}"
            logger.info "Service charges must be configured in Clover dashboard"
            nil
          end
        end

        # Apply a service charge to a specific order
        # Clover requires either an existing service charge ID or creating one inline
        # @param order_id [String] The order ID
        # @param name [String] The name of the service charge
        # @param percentage [Float] The percentage
        # @param service_charge_id [String, nil] Optional ID of existing service charge
        def apply_service_charge_to_order(order_id, name:, percentage:, service_charge_id: nil)
          logger.info "Applying service charge '#{name}' (#{percentage}%) to order #{order_id}"

          percentage_decimal = (percentage * 100).to_i

          # If we have an ID, use it; otherwise try to find or create one
          if service_charge_id.nil?
            # Check if a matching service charge already exists
            existing = get_service_charges.find { |sc| sc["name"]&.downcase == name.downcase }
            service_charge_id = existing&.dig("id")

            # If no existing charge, create one first
            if service_charge_id.nil?
              new_charge = create_service_charge(name: name, percentage: percentage)
              service_charge_id = new_charge&.dig("id")
            end
          end

          # If we still don't have an ID, we can't apply the charge
          if service_charge_id.nil?
            logger.warn "Could not create or find service charge, using inline approach"
            # Try inline approach with just the amount (not percentage)
            # This is a fallback for sandbox limitations
            return nil
          end

          payload = {
            "id" => service_charge_id,
            "name" => name,
            "percentageDecimal" => percentage_decimal
          }

          request(:post, endpoint("orders/#{order_id}/service_charge"), payload: payload)
        end

        # Get the auto-gratuity service charge if it exists
        def get_auto_gratuity_charge
          charges = get_service_charges
          charges.find { |c| c["name"]&.downcase&.include?("auto") || c["name"]&.downcase&.include?("gratuity") }
        end

        # Setup default auto-gratuity service charge if it doesn't exist
        def setup_auto_gratuity(percentage: DEFAULT_AUTO_GRATUITY_PERCENTAGE)
          existing = get_auto_gratuity_charge

          if existing
            logger.info "Auto-gratuity service charge already exists: #{existing['name']}"
            return existing
          end

          create_service_charge(
            name: AUTO_GRATUITY_NAME,
            percentage: percentage
          )
        end
      end
    end
  end
end
