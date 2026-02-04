# frozen_string_literal: true

require "oauth2"

module CloverSandboxSimulator
  module Services
    module Clover
      # Manages Clover OAuth2 authentication
      # Handles token refresh and validation using omniauth-clover-oauth2
      #
      # Usage:
      #   oauth = OauthService.new
      #
      #   # Check if token needs refresh
      #   if oauth.token_expired?
      #     new_token = oauth.refresh_token
      #   end
      #
      #   # Get authorization URL for initial auth
      #   url = oauth.authorization_url
      #
      class OauthService < BaseService
        # Sandbox OAuth endpoints
        SANDBOX_AUTH_URL = "https://sandbox.dev.clover.com/oauth/v2/authorize"
        SANDBOX_TOKEN_URL = "https://sandbox.dev.clover.com/oauth/v2/token"

        # Production OAuth endpoints
        PRODUCTION_AUTH_URL = "https://www.clover.com/oauth/v2/authorize"
        PRODUCTION_TOKEN_URL = "https://www.clover.com/oauth/v2/token"

        attr_reader :app_id, :app_secret

        def initialize(config: nil, app_id: nil, app_secret: nil)
          super(config: config)
          @app_id = app_id || ENV.fetch("CLOVER_APP_ID", nil)
          @app_secret = app_secret || ENV.fetch("CLOVER_APP_SECRET", nil)
        end

        # Check if OAuth credentials are configured
        def oauth_configured?
          !app_id.nil? && !app_id.empty? &&
            !app_secret.nil? && !app_secret.empty?
        end

        # Get the authorization URL for user consent
        #
        # @param redirect_uri [String] Callback URL after authorization
        # @param merchant_id [String, nil] Optional merchant ID to pre-select
        # @return [String] Authorization URL
        def authorization_url(redirect_uri:, merchant_id: nil)
          validate_oauth_config!

          params = {
            client_id: app_id,
            redirect_uri: redirect_uri,
            response_type: "code"
          }
          params[:merchant_id] = merchant_id if merchant_id

          "#{auth_endpoint}?#{URI.encode_www_form(params)}"
        end

        # Exchange authorization code for tokens
        #
        # @param code [String] Authorization code from callback
        # @param redirect_uri [String] Same redirect URI used in authorization
        # @return [Hash] Token response with access_token, refresh_token, etc.
        def exchange_code(code:, redirect_uri:)
          validate_oauth_config!

          logger.info "Exchanging authorization code for tokens..."

          response = RestClient.post(
            token_endpoint,
            {
              client_id: app_id,
              client_secret: app_secret,
              code: code,
              redirect_uri: redirect_uri,
              grant_type: "authorization_code"
            },
            { "Content-Type" => "application/x-www-form-urlencoded" }
          )

          tokens = JSON.parse(response.body)
          logger.info "Token exchange successful"
          tokens
        rescue RestClient::ExceptionWithResponse => e
          handle_oauth_error(e)
        end

        # Refresh an expired access token
        #
        # @param refresh_token [String] The refresh token
        # @return [Hash] New token response
        def refresh_token(refresh_token)
          validate_oauth_config!

          logger.info "Refreshing access token..."

          response = RestClient.post(
            token_endpoint,
            {
              client_id: app_id,
              client_secret: app_secret,
              refresh_token: refresh_token,
              grant_type: "refresh_token"
            },
            { "Content-Type" => "application/x-www-form-urlencoded" }
          )

          tokens = JSON.parse(response.body)
          logger.info "Token refresh successful"
          tokens
        rescue RestClient::ExceptionWithResponse => e
          handle_oauth_error(e)
        end

        # Check if the current API token is expired
        # Clover JWT tokens have an 'exp' claim
        #
        # @param token [String, nil] Token to check (defaults to config.api_token)
        # @return [Boolean] True if token is expired or invalid
        def token_expired?(token = nil)
          token ||= config.api_token
          return true if token.nil? || token.empty? || token == "NEEDS_REFRESH"

          # Decode JWT to check expiration
          parts = token.split(".")
          return true unless parts.length == 3

          payload = JSON.parse(Base64.decode64(parts[1]))
          exp = payload["exp"]

          return true unless exp

          # Token is expired if exp is in the past (with 60s buffer)
          Time.now.to_i >= (exp - 60)
        rescue StandardError => e
          logger.debug "Could not decode token: #{e.message}"
          true
        end

        # Get token info from a JWT
        #
        # @param token [String] JWT token to decode
        # @return [Hash] Decoded payload
        def decode_token(token)
          parts = token.split(".")
          raise ArgumentError, "Invalid JWT format" unless parts.length == 3

          payload = JSON.parse(Base64.decode64(parts[1]))

          {
            merchant_id: payload["merchant_uuid"],
            app_id: payload["app_uuid"],
            issued_at: Time.at(payload["iat"]),
            expires_at: Time.at(payload["exp"]),
            permissions: payload["permission_bitmap"]
          }
        rescue StandardError => e
          logger.error "Failed to decode token: #{e.message}"
          {}
        end

        # Update the configuration with a new token
        #
        # @param access_token [String] New access token
        def update_config_token(access_token)
          config.api_token = access_token
          logger.info "Configuration updated with new token"
        end

        # Refresh the token for the current merchant using stored refresh token
        # Updates both config and .env.json
        #
        # @return [Hash, nil] New token response or nil on failure
        def refresh_current_merchant_token
          unless config.refresh_token && !config.refresh_token.empty?
            logger.warn "No refresh token available for current merchant"
            return nil
          end

          tokens = refresh_token(config.refresh_token)
          return nil unless tokens

          # Update config
          update_config_token(tokens["access_token"])

          # Save to .env.json
          save_tokens_to_json(
            config.merchant_id,
            access_token: tokens["access_token"],
            refresh_token: tokens["refresh_token"]
          )

          tokens
        end

        # Save tokens to .env.json for a specific merchant
        #
        # @param merchant_id [String] Merchant ID to update
        # @param access_token [String, nil] New access token
        # @param refresh_token [String, nil] New refresh token
        def save_tokens_to_json(merchant_id, access_token: nil, refresh_token: nil)
          file_path = config.class::MERCHANTS_FILE
          return unless File.exist?(file_path)

          merchants = JSON.parse(File.read(file_path))

          merchant = merchants.find { |m| m["CLOVER_MERCHANT_ID"] == merchant_id }
          if merchant
            merchant["CLOVER_API_TOKEN"] = access_token if access_token
            merchant["CLOVER_REFRESH_TOKEN"] = refresh_token if refresh_token
            # Also update config
            config.refresh_token = refresh_token if refresh_token

            File.write(file_path, JSON.pretty_generate(merchants))
            logger.info "Tokens saved to .env.json for merchant #{merchant_id}"
          else
            logger.warn "Merchant #{merchant_id} not found in .env.json"
          end
        rescue StandardError => e
          logger.error "Failed to save tokens: #{e.message}"
        end

        # Alias for backwards compatibility
        def save_token_to_json(merchant_id, access_token)
          save_tokens_to_json(merchant_id, access_token: access_token)
        end

        private

        def validate_oauth_config!
          raise ConfigurationError, "CLOVER_APP_ID is required for OAuth" if app_id.nil? || app_id.empty?
          raise ConfigurationError, "CLOVER_APP_SECRET is required for OAuth" if app_secret.nil? || app_secret.empty?
        end

        def sandbox?
          config.environment.include?("sandbox")
        end

        def auth_endpoint
          sandbox? ? SANDBOX_AUTH_URL : PRODUCTION_AUTH_URL
        end

        def token_endpoint
          sandbox? ? SANDBOX_TOKEN_URL : PRODUCTION_TOKEN_URL
        end

        def handle_oauth_error(error)
          body = begin
            JSON.parse(error.response.body)
          rescue StandardError
            { "error" => error.response.body }
          end

          error_msg = body["error_description"] || body["error"] || body["message"] || error.message
          logger.error "OAuth Error (#{error.http_code}): #{error_msg}"
          raise ApiError, "OAuth Error: #{error_msg}"
        end
      end
    end
  end
end
