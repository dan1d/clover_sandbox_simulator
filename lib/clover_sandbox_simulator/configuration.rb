# frozen_string_literal: true

module CloverSandboxSimulator
  class Configuration
    attr_accessor :merchant_id, :merchant_name, :api_token, :environment, :log_level, :tax_rate, :business_type,
                  :public_token, :private_token, :ecommerce_environment, :tokenizer_environment,
                  :app_id, :app_secret, :refresh_token

    # Path to merchants JSON file
    MERCHANTS_FILE = File.join(File.dirname(__FILE__), "..", "..", ".env.json")

    def initialize
      @merchant_id   = ENV.fetch("CLOVER_MERCHANT_ID", nil)
      @merchant_name = ENV.fetch("CLOVER_MERCHANT_NAME", nil)
      @api_token     = ENV.fetch("CLOVER_API_TOKEN", nil)
      @environment   = normalize_url(ENV.fetch("CLOVER_ENVIRONMENT", "https://sandbox.dev.clover.com/"))
      @log_level     = parse_log_level(ENV.fetch("LOG_LEVEL", "INFO"))
      @tax_rate      = ENV.fetch("TAX_RATE", "8.25").to_f
      @business_type = ENV.fetch("BUSINESS_TYPE", "restaurant").to_sym

      # Ecommerce API tokens (for card payments and refunds)
      @public_token  = ENV.fetch("PUBLIC_TOKEN", nil)
      @private_token = ENV.fetch("PRIVATE_TOKEN", nil)
      @ecommerce_environment = normalize_url(ENV.fetch("ECOMMERCE_ENVIRONMENT", "https://scl-sandbox.dev.clover.com/"))
      @tokenizer_environment = normalize_url(ENV.fetch("TOKENIZER_ENVIRONMENT", "https://token-sandbox.dev.clover.com/"))

      # OAuth credentials (for token refresh)
      @app_id = ENV.fetch("CLOVER_APP_ID", nil)
      @app_secret = ENV.fetch("CLOVER_APP_SECRET", nil)
      @refresh_token = ENV.fetch("CLOVER_REFRESH_TOKEN", nil)

      # Load from .env.json if merchant_id not set in ENV
      load_from_merchants_file if @merchant_id.nil? || @merchant_id.empty?
    end

    # Check if OAuth is configured for token refresh
    def oauth_enabled?
      !app_id.nil? && !app_id.empty? &&
        !app_secret.nil? && !app_secret.empty?
    end

    # Load configuration for a specific merchant from .env.json
    #
    # @param merchant_id [String, nil] Merchant ID to load (nil for first merchant)
    # @param index [Integer, nil] Index of merchant in the list (0-based)
    # @return [self]
    def load_merchant(merchant_id: nil, index: nil)
      merchants = load_merchants_file
      return self if merchants.empty?

      merchant = if merchant_id
                   merchants.find { |m| m["CLOVER_MERCHANT_ID"] == merchant_id }
                 elsif index
                   merchants[index]
                 else
                   merchants.first
                 end

      if merchant
        apply_merchant_config(merchant)
        logger.info "Loaded merchant: #{@merchant_name} (#{@merchant_id})"
      else
        logger.warn "Merchant not found: #{merchant_id || "index #{index}"}"
      end

      self
    end

    # List all available merchants from .env.json
    #
    # @return [Array<Hash>] Array of merchant configs
    def available_merchants
      load_merchants_file.map do |m|
        {
          id: m["CLOVER_MERCHANT_ID"],
          name: m["CLOVER_MERCHANT_NAME"],
          has_ecommerce: !m["PUBLIC_TOKEN"].to_s.empty? && !m["PRIVATE_TOKEN"].to_s.empty?
        }
      end
    end

    def validate!
      raise ConfigurationError, "CLOVER_MERCHANT_ID is required" if merchant_id.nil? || merchant_id.empty?

      # API token is only required for Platform API operations
      # Ecommerce-only operations can work without it
      true
    end

    # Validate for Platform API operations (requires OAuth token)
    def validate_platform!
      validate!
      raise ConfigurationError, "CLOVER_API_TOKEN is required for Platform API" if api_token.nil? || api_token.empty?

      true
    end

    # Check if Platform API is configured (has OAuth token)
    def platform_enabled?
      !api_token.nil? && !api_token.empty? && api_token != "NEEDS_REFRESH"
    end

    # Check if Ecommerce API is configured
    def ecommerce_enabled?
      !public_token.nil? && !public_token.empty? &&
        !private_token.nil? && !private_token.empty?
    end

    # Validate Ecommerce configuration
    def validate_ecommerce!
      raise ConfigurationError, "PUBLIC_TOKEN is required for Ecommerce API" if public_token.nil? || public_token.empty?
      raise ConfigurationError, "PRIVATE_TOKEN is required for Ecommerce API" if private_token.nil? || private_token.empty?

      true
    end

    def logger
      @logger ||= Logger.new($stdout).tap do |log|
        log.level = @log_level
        log.formatter = proc do |severity, datetime, _progname, msg|
          timestamp = datetime.strftime("%Y-%m-%d %H:%M:%S")
          "[#{timestamp}] #{severity.ljust(5)} | #{msg}\n"
        end
      end
    end

    private

    def load_from_merchants_file
      merchants = load_merchants_file
      return if merchants.empty?

      # Use first merchant by default
      apply_merchant_config(merchants.first)
    end

    def load_merchants_file
      return [] unless File.exist?(MERCHANTS_FILE)

      JSON.parse(File.read(MERCHANTS_FILE))
    rescue JSON::ParserError => e
      warn "Failed to parse #{MERCHANTS_FILE}: #{e.message}"
      []
    end

    def apply_merchant_config(merchant)
      @merchant_id   = merchant["CLOVER_MERCHANT_ID"]
      @merchant_name = merchant["CLOVER_MERCHANT_NAME"]
      # Support both CLOVER_ACTUAL_API_TOKEN (static token) and CLOVER_API_TOKEN (OAuth token)
      # Prefer the static API token if available
      if merchant["CLOVER_ACTUAL_API_TOKEN"].to_s.length > 10
        @api_token = merchant["CLOVER_ACTUAL_API_TOKEN"]
      elsif merchant["CLOVER_API_TOKEN"].to_s.length > 10
        @api_token = merchant["CLOVER_API_TOKEN"]
      end
      @refresh_token = merchant["CLOVER_REFRESH_TOKEN"] if merchant["CLOVER_REFRESH_TOKEN"].to_s.length > 10
      @public_token  = merchant["PUBLIC_TOKEN"] unless merchant["PUBLIC_TOKEN"].to_s.empty?
      @private_token = merchant["PRIVATE_TOKEN"] unless merchant["PRIVATE_TOKEN"].to_s.empty?
    end

    def normalize_url(url)
      url = url.strip
      url.end_with?("/") ? url : "#{url}/"
    end

    def parse_log_level(level)
      case level.to_s.upcase
      when "DEBUG" then Logger::DEBUG
      when "INFO"  then Logger::INFO
      when "WARN"  then Logger::WARN
      when "ERROR" then Logger::ERROR
      when "FATAL" then Logger::FATAL
      else Logger::INFO
      end
    end
  end
end
