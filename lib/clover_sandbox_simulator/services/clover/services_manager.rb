# frozen_string_literal: true

module CloverSandboxSimulator
  module Services
    module Clover
      # Central manager for all Clover services
      # Provides lazy-loaded access to all service classes
      class ServicesManager
        attr_reader :config

        def initialize(config: nil)
          @config = config || CloverSandboxSimulator.configuration
        end

        def inventory
          @inventory ||= InventoryService.new(config: config)
        end

        def tender
          @tender ||= TenderService.new(config: config)
        end

        def tax
          @tax ||= TaxService.new(config: config)
        end

        def discount
          @discount ||= DiscountService.new(config: config)
        end

        def order
          @order ||= OrderService.new(config: config)
        end

        def payment
          @payment ||= PaymentService.new(config: config)
        end

        def employee
          @employee ||= EmployeeService.new(config: config)
        end

        def customer
          @customer ||= CustomerService.new(config: config)
        end

        def refund
          @refund ||= RefundService.new(config: config)
        end

        def gift_card
          @gift_card ||= GiftCardService.new(config: config)
        end

        def ecommerce
          @ecommerce ||= EcommerceService.new(config: config)
        end

        def oauth
          @oauth ||= OauthService.new(config: config)
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
      end
    end
  end
end
