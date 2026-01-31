# frozen_string_literal: true

require "zeitwerk"
require "logger"
require "json"
require "rest-client"
require "dotenv"

# Load environment variables
Dotenv.load

module CloverSandboxSimulator
  class Error < StandardError; end
  class ConfigurationError < Error; end
  class ApiError < Error; end

  class << self
    attr_writer :configuration

    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
    end

    def logger
      configuration.logger
    end

    def root
      File.expand_path("..", __dir__)
    end
  end
end

# Set up Zeitwerk autoloader
loader = Zeitwerk::Loader.for_gem
loader.setup

# Eager load in production
loader.eager_load if ENV["RACK_ENV"] == "production"
