# frozen_string_literal: true

module CloverSandboxSimulator
  module Services
    module Clover
      # Manages Clover Ecommerce API operations
      # Handles card tokenization, charges, and refunds via the Ecommerce API
      #
      # The Ecommerce API is separate from the Platform API and uses different endpoints:
      # - Tokenization: https://token-sandbox.dev.clover.com/v1/tokens
      # - Charges/Refunds: https://scl-sandbox.dev.clover.com/v1/
      #
      # Requires PUBLIC_TOKEN (for tokenization) and PRIVATE_TOKEN (for charges/refunds)
      class EcommerceService < BaseService
        # Test card numbers for sandbox
        TEST_CARDS = {
          visa: "4242424242424242",
          visa_debit: "4005562231212123",
          mastercard: "5200828282828210",
          amex: "378282246310005",
          discover: "6011111111111117",
          # Cards that simulate specific responses
          decline: "4000000000000002",
          insufficient_funds: "4000000000009995"
        }.freeze

        # Create a card token for use in charges
        #
        # @param card_number [String] Card number (use TEST_CARDS for sandbox)
        # @param exp_month [String] Expiration month (01-12)
        # @param exp_year [String] Expiration year (4 digits)
        # @param cvv [String] CVV code
        # @return [Hash, nil] Token response with id, or nil on failure
        def create_card_token(card_number:, exp_month:, exp_year:, cvv: "123")
          validate_ecommerce_config!

          logger.info "Creating card token for card ending in #{card_number[-4..]}"

          payload = {
            "card" => {
              "number" => card_number,
              "exp_month" => exp_month.to_s.rjust(2, "0"),
              "exp_year" => exp_year.to_s,
              "cvv" => cvv.to_s
            }
          }

          response = ecommerce_request(:post, "#{config.tokenizer_environment}v1/tokens",
                                       payload: payload,
                                       auth_type: :public)

          if response && response["id"]
            logger.info "Card token created: #{response['id']} (#{response.dig('card', 'brand')})"
          end

          response
        end

        # Create a random test card token
        # Rotates between different card types to avoid rate limits
        #
        # @param card_type [Symbol, nil] Type of card (nil for random rotation)
        # @return [Hash, nil] Token response
        def create_test_card_token(card_type: nil)
          # Rotate between different card types to avoid "sale count per card" limits
          card_types = [:visa, :visa_debit, :mastercard, :discover]
          card_type ||= card_types.sample

          card_number = TEST_CARDS[card_type] || TEST_CARDS[:visa]
          exp_year = (Time.now.year + 3).to_s
          # Vary expiration month to create different card fingerprints
          exp_month = format("%02d", rand(1..12))

          create_card_token(
            card_number: card_number,
            exp_month: exp_month,
            exp_year: exp_year,
            cvv: card_type == :amex ? "1234" : "123"
          )
        end

        # Create a charge (card payment)
        #
        # @param amount [Integer] Amount in cents
        # @param source [String] Card token ID (clv_...)
        # @param currency [String] Currency code (default: usd)
        # @param description [String, nil] Optional description
        # @param order_id [String, nil] Optional order ID to link the charge
        # @return [Hash, nil] Charge response with id, or nil on failure
        def create_charge(amount:, source:, currency: "usd", description: nil, order_id: nil)
          validate_ecommerce_config!

          logger.info "Creating charge: $#{amount / 100.0} with token #{source[0..20]}..."

          payload = {
            "amount" => amount,
            "currency" => currency,
            "source" => source
          }
          payload["description"] = description if description
          payload["order_id"] = order_id if order_id

          # Generate unique idempotency key
          idempotency_key = "charge-#{SecureRandom.uuid}"

          response = ecommerce_request(:post, "#{config.ecommerce_environment}v1/charges",
                                       payload: payload,
                                       auth_type: :private,
                                       idempotency_key: idempotency_key)

          if response && response["id"]
            logger.info "Charge successful: #{response['id']} - $#{response['amount'] / 100.0} (#{response['status']})"
          else
            logger.error "Charge failed: #{response.inspect}"
          end

          response
        end

        # Create a charge with a new test card in one step
        #
        # @param amount [Integer] Amount in cents
        # @param card_type [Symbol] Type of test card
        # @return [Hash, nil] Charge response
        def create_test_charge(amount:, card_type: :visa)
          token = create_test_card_token(card_type: card_type)
          return nil unless token && token["id"]

          create_charge(amount: amount, source: token["id"])
        end

        # Create a refund for a charge
        #
        # @param charge_id [String] The charge ID to refund
        # @param amount [Integer, nil] Amount to refund in cents (nil for full refund)
        # @param reason [String, nil] Reason for refund
        # @return [Hash, nil] Refund response
        def create_refund(charge_id:, amount: nil, reason: nil)
          validate_ecommerce_config!

          if amount
            logger.info "Creating partial refund for charge #{charge_id}: $#{amount / 100.0}"
          else
            logger.info "Creating full refund for charge #{charge_id}"
          end

          payload = { "charge" => charge_id }
          payload["amount"] = amount if amount
          payload["reason"] = reason if reason

          idempotency_key = "refund-#{SecureRandom.uuid}"

          response = ecommerce_request(:post, "#{config.ecommerce_environment}v1/refunds",
                                       payload: payload,
                                       auth_type: :private,
                                       idempotency_key: idempotency_key)

          if response && response["id"]
            logger.info "Refund successful: #{response['id']} - $#{(response['amount'] || 0) / 100.0}"
          else
            logger.error "Refund failed: #{response.inspect}"
          end

          response
        end

        # Get a charge by ID
        #
        # @param charge_id [String] The charge ID
        # @return [Hash, nil] Charge details
        def get_charge(charge_id)
          validate_ecommerce_config!

          ecommerce_request(:get, "#{config.ecommerce_environment}v1/charges/#{charge_id}",
                            auth_type: :private)
        end

        # Get a refund by ID
        #
        # @param refund_id [String] The refund ID
        # @return [Hash, nil] Refund details
        def get_refund(refund_id)
          validate_ecommerce_config!

          ecommerce_request(:get, "#{config.ecommerce_environment}v1/refunds/#{refund_id}",
                            auth_type: :private)
        end

        # Check if Ecommerce API is available
        def ecommerce_available?
          config.ecommerce_enabled?
        end

        private

        def validate_ecommerce_config!
          config.validate_ecommerce!
        end

        # Make HTTP request to Ecommerce API
        def ecommerce_request(method, url, payload: nil, auth_type: :private, idempotency_key: nil)
          log_request(method, url, payload)
          start_time = Time.now

          response = execute_ecommerce_request(method, url, payload, auth_type, idempotency_key)

          duration_ms = ((Time.now - start_time) * 1000).round(2)
          log_response(response, duration_ms)

          parse_response(response)
        rescue RestClient::ExceptionWithResponse => e
          handle_ecommerce_error(e)
        rescue StandardError => e
          logger.error "Ecommerce request failed: #{e.message}"
          raise ApiError, e.message
        end

        def execute_ecommerce_request(method, url, payload, auth_type, idempotency_key)
          hdrs = ecommerce_headers(auth_type, idempotency_key)

          case method
          when :get    then RestClient.get(url, hdrs)
          when :post   then RestClient.post(url, payload&.to_json, hdrs)
          when :put    then RestClient.put(url, payload&.to_json, hdrs)
          when :delete then RestClient.delete(url, hdrs)
          else raise ArgumentError, "Unsupported HTTP method: #{method}"
          end
        end

        def ecommerce_headers(auth_type, idempotency_key = nil)
          hdrs = {
            "Content-Type" => "application/json",
            "Accept" => "application/json"
          }

          case auth_type
          when :public
            # Tokenization uses apikey header with public token
            hdrs["apikey"] = config.public_token
          when :private
            # Charges/refunds use Bearer token with private token
            hdrs["Authorization"] = "Bearer #{config.private_token}"
          end

          hdrs["Idempotency-Key"] = idempotency_key if idempotency_key

          hdrs
        end

        def handle_ecommerce_error(error)
          body = begin
            JSON.parse(error.response.body)
          rescue StandardError
            { "message" => error.response.body }
          end

          error_message = body.dig("error", "message") || body["message"] || body.to_s
          logger.error "Ecommerce API Error (#{error.http_code}): #{error_message}"
          raise ApiError, "HTTP #{error.http_code}: #{error_message}"
        end

        def log_request(method, url, payload)
          logger.debug "→ ECOMM #{method.to_s.upcase} #{url}"
          logger.debug "  Payload: #{payload.inspect}" if payload
        end

        def log_response(response, duration_ms)
          logger.debug "← #{response.code} (#{duration_ms}ms)"
        end

        def parse_response(response)
          return nil if response.body.nil? || response.body.empty?

          JSON.parse(response.body)
        rescue JSON::ParserError => e
          logger.error "Failed to parse ecommerce response: #{e.message}"
          raise ApiError, "Invalid JSON response"
        end
      end
    end
  end
end
