# frozen_string_literal: true

module CloverSandboxSimulator
  module Services
    module Clover
      # Central manager for all Clover services
      # Provides thread-safe, lazy-loaded access to all service classes
      class ServicesManager
        attr_reader :config

        def initialize(config: nil)
          @config = config || CloverSandboxSimulator.configuration
          @mutex = Mutex.new
        end

        def inventory
          thread_safe_memoize(:@inventory) { InventoryService.new(config: config) }
        end

        def tender
          thread_safe_memoize(:@tender) { TenderService.new(config: config) }
        end

        def tax
          thread_safe_memoize(:@tax) { TaxService.new(config: config) }
        end

        def discount
          thread_safe_memoize(:@discount) { DiscountService.new(config: config) }
        end

        def order
          thread_safe_memoize(:@order) { OrderService.new(config: config) }
        end

        def payment
          thread_safe_memoize(:@payment) { PaymentService.new(config: config) }
        end

        def employee
          thread_safe_memoize(:@employee) { EmployeeService.new(config: config) }
        end

        def customer
          thread_safe_memoize(:@customer) { CustomerService.new(config: config) }
        end

        def refund
          thread_safe_memoize(:@refund) { RefundService.new(config: config) }
        end

        def gift_card
          thread_safe_memoize(:@gift_card) { GiftCardService.new(config: config) }
        end

        def ecommerce
          thread_safe_memoize(:@ecommerce) { EcommerceService.new(config: config) }
        end

        def oauth
          thread_safe_memoize(:@oauth) { OauthService.new(config: config) }
        end

        def service_charge
          thread_safe_memoize(:@service_charge) { ServiceChargeService.new(config: config) }
        end

        def shift
          thread_safe_memoize(:@shift) { ShiftService.new(config: config) }
        end

        def order_type
          thread_safe_memoize(:@order_type) { OrderTypeService.new(config: config) }
        end

        def cash_event
          thread_safe_memoize(:@cash_event) { CashEventService.new(config: config) }
        end

        # Check if Ecommerce API is available
        def ecommerce_available?
          config.ecommerce_enabled?
        end

        # Check if OAuth is configured
        def oauth_available?
          oauth.oauth_configured?
        end

        # Check if current token is expired
        def token_expired?
          oauth.token_expired?
        end

        # Clear all cached service instances
        def clear_services
          @mutex.synchronize do
            instance_variables.each do |var|
              next if var == :@config || var == :@mutex

              instance_variable_set(var, nil)
            end
          end
        end

        private

        # Thread-safe memoization pattern
        def thread_safe_memoize(ivar_name)
          # Fast path: return if already set
          value = instance_variable_get(ivar_name)
          return value if value

          # Slow path: synchronize and check again
          @mutex.synchronize do
            value = instance_variable_get(ivar_name)
            return value if value

            value = yield
            instance_variable_set(ivar_name, value)
            value
          end
        end
      end
    end
  end
end
