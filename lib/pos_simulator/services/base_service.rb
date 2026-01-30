# frozen_string_literal: true

module PosSimulator
  module Services
    # Base service for all API interactions
    # Provides HTTP client, logging, and error handling
    class BaseService
      attr_reader :config, :logger

      def initialize(config: nil)
        @config = config || PosSimulator.configuration
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
    end
  end
end
