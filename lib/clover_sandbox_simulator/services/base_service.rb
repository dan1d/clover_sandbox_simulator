# frozen_string_literal: true

module CloverSandboxSimulator
  module Services
    # Base service for all API interactions
    # Provides HTTP client, logging, and error handling
    class BaseService
      attr_reader :config, :logger

      def initialize(config: nil)
        @config = config || CloverSandboxSimulator.configuration
        @config.validate!
        @logger = @config.logger
      end

      protected

      # Make HTTP request to Clover API
      #
      # @param method [Symbol] HTTP method (:get, :post, :put, :delete)
      # @param path [String] API endpoint path
      # @param payload [Hash, nil] Request body for POST/PUT
      # @param params [Hash, nil] Query parameters
      # @return [Hash, nil] Parsed JSON response
      def request(method, path, payload: nil, params: nil)
        url = build_url(path, params)

        log_request(method, url, payload)
        start_time = Time.now

        response = execute_request(method, url, payload)

        duration_ms = ((Time.now - start_time) * 1000).round(2)
        log_response(response, duration_ms)

        parse_response(response)
      rescue RestClient::ExceptionWithResponse => e
        handle_api_error(e)
      rescue StandardError => e
        logger.error "Request failed: #{e.message}"
        raise ApiError, e.message
      end

      # Build endpoint path with merchant ID
      #
      # @param path [String] Relative path after merchant ID
      # @return [String] Full endpoint path
      def endpoint(path)
        "v3/merchants/#{config.merchant_id}/#{path}"
      end

      private

      def headers
        {
          "Authorization" => "Bearer #{config.api_token}",
          "Content-Type" => "application/json",
          "Accept" => "application/json"
        }
      end

      def build_url(path, params = nil)
        base = path.start_with?("http") ? path : "#{config.environment}#{path}"
        return base unless params&.any?

        uri = URI(base)
        uri.query = URI.encode_www_form(params)
        uri.to_s
      end

      def execute_request(method, url, payload)
        case method
        when :get    then RestClient.get(url, headers)
        when :post   then RestClient.post(url, payload&.to_json, headers)
        when :put    then RestClient.put(url, payload&.to_json, headers)
        when :delete then RestClient.delete(url, headers)
        else raise ArgumentError, "Unsupported HTTP method: #{method}"
        end
      end

      def parse_response(response)
        return nil if response.body.nil? || response.body.empty?

        JSON.parse(response.body)
      rescue JSON::ParserError => e
        logger.error "Failed to parse response: #{e.message}"
        raise ApiError, "Invalid JSON response"
      end

      def handle_api_error(error)
        body = begin
          JSON.parse(error.response.body)
        rescue StandardError
          { "message" => error.response.body }
        end

        logger.error "API Error (#{error.http_code}): #{body}"
        raise ApiError, "HTTP #{error.http_code}: #{body["message"] || body}"
      end

      def log_request(method, url, payload)
        logger.debug "→ #{method.to_s.upcase} #{url}"
        logger.debug "  Payload: #{payload.inspect}" if payload
      end

      def log_response(response, duration_ms)
        logger.debug "← #{response.code} (#{duration_ms}ms)"
      end

      # ============================================
      # STANDARDIZED ERROR HANDLING HELPERS
      # ============================================

      # Execute a block with API error fallback
      # @param fallback [Object] Value to return on error
      # @param log_level [Symbol] Log level for error (:debug, :warn, :error)
      # @param reraise_on [Array<Integer>] HTTP codes to reraise instead of fallback
      # @yield Block to execute
      # @return [Object] Block result or fallback
      def with_api_fallback(fallback: nil, log_level: :debug, reraise_on: [])
        yield
      rescue ApiError => e
        # Reraise if it's a critical error code
        if reraise_on.any? { |code| e.message.include?("HTTP #{code}") }
          raise
        end

        logger.send(log_level, "API error (using fallback): #{e.message}")
        fallback
      rescue StandardError => e
        logger.send(log_level, "Error (using fallback): #{e.message}")
        fallback
      end

      # Execute a block, handling sandbox limitations (405 errors)
      # @param simulated_response [Object] Response to return if sandbox doesn't support the operation
      # @yield Block to execute
      # @return [Object] Block result or simulated response
      def with_sandbox_fallback(simulated_response: nil)
        yield
      rescue ApiError => e
        if e.message.include?("405")
          logger.warn "Operation not supported in sandbox environment"
          simulated_response
        else
          raise
        end
      end

      # Safe getter for nested hash values with logging
      # @param hash [Hash] The hash to extract from
      # @param keys [Array] Keys to dig into
      # @param default [Object] Default value if not found
      # @return [Object] The value or default
      def safe_dig(hash, *keys, default: nil)
        return default if hash.nil?

        hash.dig(*keys) || default
      rescue StandardError
        default
      end
    end
  end
end
