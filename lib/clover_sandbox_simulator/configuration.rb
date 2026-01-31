# frozen_string_literal: true

module CloverSandboxSimulator
  class Configuration
    attr_accessor :merchant_id, :api_token, :environment, :log_level, :tax_rate, :business_type

    def initialize
      @merchant_id   = ENV.fetch("CLOVER_MERCHANT_ID", nil)
      @api_token     = ENV.fetch("CLOVER_API_TOKEN", nil)
      @environment   = normalize_url(ENV.fetch("CLOVER_ENVIRONMENT", "https://sandbox.dev.clover.com/"))
      @log_level     = parse_log_level(ENV.fetch("LOG_LEVEL", "INFO"))
      @tax_rate      = ENV.fetch("TAX_RATE", "8.25").to_f
      @business_type = ENV.fetch("BUSINESS_TYPE", "restaurant").to_sym
    end

    def validate!
      raise ConfigurationError, "CLOVER_MERCHANT_ID is required" if merchant_id.nil? || merchant_id.empty?
      raise ConfigurationError, "CLOVER_API_TOKEN is required" if api_token.nil? || api_token.empty?

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
