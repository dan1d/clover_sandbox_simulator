# frozen_string_literal: true

require "bundler/setup"
require "clover_sandbox_simulator"
require "webmock/rspec"
require "vcr"
require "json"

# Disable real HTTP connections in tests
WebMock.disable_net_connect!(allow_localhost: true)

# Load merchants from .env.json for integration tests.
# Supports both the legacy array format and the new object format:
#   { "DATABASE_URL": "...", "merchants": [...] }
def load_env_json
  env_path = File.expand_path("../../.env.json", __FILE__)
  return [] unless File.exist?(env_path)

  data = JSON.parse(File.read(env_path))
  return data if data.is_a?(Array) # legacy format

  data.fetch("merchants", [])
end

# Get specific merchant config by name
def get_merchant_config(name)
  merchants = load_env_json
  merchants.find { |m| m["CLOVER_MERCHANT_NAME"] == name }
end

# VCR configuration
VCR.configure do |config|
  config.cassette_library_dir = "spec/cassettes"
  config.hook_into :webmock
  config.configure_rspec_metadata!

  # Allow HTTP connections when VCR is managing (recording/replaying)
  config.allow_http_connections_when_no_cassette = false

  # Load all merchants and filter their sensitive data
  load_env_json.each_with_index do |merchant, idx|
    config.filter_sensitive_data("<MERCHANT_#{idx}_ID>") { merchant["CLOVER_MERCHANT_ID"] }
    config.filter_sensitive_data("<MERCHANT_#{idx}_API_TOKEN>") { merchant["CLOVER_API_TOKEN"] }
    config.filter_sensitive_data("<MERCHANT_#{idx}_ACCESS_TOKEN>") { merchant["CLOVER_ACCESS_TOKEN"] }
    config.filter_sensitive_data("<MERCHANT_#{idx}_REFRESH_TOKEN>") { merchant["CLOVER_REFRESH_TOKEN"] }
    config.filter_sensitive_data("<MERCHANT_#{idx}_PUBLIC_TOKEN>") { merchant["PUBLIC_TOKEN"] }
    config.filter_sensitive_data("<MERCHANT_#{idx}_PRIVATE_TOKEN>") { merchant["PRIVATE_TOKEN"] }
  end

  # Also filter from ENV variables
  config.filter_sensitive_data("<CLOVER_API_TOKEN>") { ENV["CLOVER_API_TOKEN"] }
  config.filter_sensitive_data("<CLOVER_MERCHANT_ID>") { ENV["CLOVER_MERCHANT_ID"] }
  config.filter_sensitive_data("<CLOVER_ACCESS_TOKEN>") { ENV["CLOVER_ACCESS_TOKEN"] }
  config.filter_sensitive_data("<PUBLIC_TOKEN>") { ENV["PUBLIC_TOKEN"] }
  config.filter_sensitive_data("<PRIVATE_TOKEN>") { ENV["PRIVATE_TOKEN"] }

  # Allow re-recording cassettes - :new_episodes records new requests
  config.default_cassette_options = {
    record: :new_episodes,
    match_requests_on: [:method, :uri, :body]
  }

  # Ignore non-Clover requests (like localhost)
  config.ignore_localhost = true
end

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # ── FactoryBot ──────────────────────────────────────────────
  require "factory_bot"

  config.include FactoryBot::Syntax::Methods

  # Load factories from lib/ (shared between runtime and tests).
  # Uses `=` (not `<<`) to exclude the default spec/factories path — that
  # directory contains factories_spec.rb which would trigger a circular load.
  factories_path = File.expand_path("../lib/clover_sandbox_simulator/db/factories", __dir__)
  unless FactoryBot.factories.any? { |f| f.name == :business_type }
    FactoryBot.definition_file_paths = [factories_path]
    FactoryBot.find_definitions
  end

  # ── Database & DatabaseCleaner ──────────────────────────────
  # Connect to test database if available.
  # Uses clover_simulator_test by default; specs that don't need DB still pass.
  test_db_url = CloverSandboxSimulator::Database.test_database_url
  begin
    CloverSandboxSimulator::Database.connect!(test_db_url)
    require "database_cleaner/active_record"

    config.before(:suite) do
      DatabaseCleaner.strategy = :transaction
      DatabaseCleaner.clean_with(:truncation)
    end

    config.around(:each, :db) do |example|
      DatabaseCleaner.cleaning { example.run }
    end
  rescue StandardError
    # Database not available — non-DB specs will still run fine
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
