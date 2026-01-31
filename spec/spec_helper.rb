# frozen_string_literal: true

require "bundler/setup"
require "clover_sandbox_simulator"
require "webmock/rspec"
require "vcr"

# Disable real HTTP connections in tests
WebMock.disable_net_connect!(allow_localhost: true)

# VCR configuration
VCR.configure do |config|
  config.cassette_library_dir = "spec/cassettes"
  config.hook_into :webmock
  config.configure_rspec_metadata!

  # Filter sensitive data
  config.filter_sensitive_data("<CLOVER_API_TOKEN>") { ENV["CLOVER_API_TOKEN"] }
  config.filter_sensitive_data("<CLOVER_MERCHANT_ID>") { ENV["CLOVER_MERCHANT_ID"] }

  # Allow re-recording cassettes
  config.default_cassette_options = {
    record: :new_episodes,
    match_requests_on: [:method, :uri, :body]
  }
end

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end

# Create a test configuration that doesn't require env vars
def create_test_config
  config = CloverSandboxSimulator::Configuration.allocate
  config.instance_variable_set(:@merchant_id, "TEST_MERCHANT_ID")
  config.instance_variable_set(:@api_token, "TEST_API_TOKEN")
  config.instance_variable_set(:@environment, "https://sandbox.dev.clover.com/")
  config.instance_variable_set(:@log_level, Logger::ERROR)
  config.instance_variable_set(:@tax_rate, 8.25)
  config.instance_variable_set(:@business_type, :restaurant)
  config
end

# Stub environment variables for tests that need Configuration.new
def stub_clover_credentials
  # Set the global configuration directly
  CloverSandboxSimulator.configuration = create_test_config
end
