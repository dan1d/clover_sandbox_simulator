# frozen_string_literal: true

require "active_record"
require "logger"

module CloverSandboxSimulator
  # Standalone ActiveRecord connection manager for PostgreSQL.
  #
  # Provides database connectivity without requiring Rails.
  # Used for persisting Clover sandbox data (merchants, orders, etc.)
  # alongside the existing JSON-file and API-based workflows.
  #
  # When no DATABASE_URL is configured, the simulator falls back
  # to its original JSON-file behaviour — call Database.connected?
  # to check before attempting DB operations.
  #
  # @example Connect and run migrations
  #   CloverSandboxSimulator::Database.connect!("postgres://localhost:5432/clover_simulator_development")
  #   CloverSandboxSimulator::Database.migrate!
  #
  # @example Check availability for JSON fallback
  #   if CloverSandboxSimulator::Database.connected?
  #     # use ActiveRecord models
  #   else
  #     # fall back to JSON files
  #   end
  module Database
    # Directory containing ActiveRecord migration files
    MIGRATIONS_PATH = File.expand_path("db/migrate", __dir__).freeze

    # Default test database name
    TEST_DATABASE = "clover_simulator_test"

    class << self
      # Establish a standalone ActiveRecord connection to PostgreSQL.
      #
      # @param url [String] A PostgreSQL connection URL
      #   (e.g. "postgres://user:pass@localhost:5432/clover_simulator_development")
      # @return [void]
      # @raise [ArgumentError] if the URL is not a PostgreSQL URL
      # @raise [ActiveRecord::ConnectionNotEstablished] if the connection fails
      def connect!(url)
        unless url.match?(%r{\Apostgres(ql)?://}i)
          raise ArgumentError, "Expected a PostgreSQL URL (postgres:// or postgresql://), got: #{url.split('://').first}://"
        end

        ActiveRecord::Base.establish_connection(url)

        # Verify the connection is actually usable
        ActiveRecord::Base.connection.execute("SELECT 1")

        ActiveRecord::Base.logger = CloverSandboxSimulator.logger

        CloverSandboxSimulator.logger.info("Database connected: #{sanitize_url(url)}")
      end

      # Run pending migrations from lib/clover_sandbox_simulator/db/migrate/.
      #
      # Uses ActiveRecord::MigrationContext for standalone (non-Rails) usage.
      #
      # @return [void]
      def migrate!
        ensure_connected!

        CloverSandboxSimulator.logger.info("Running migrations from #{MIGRATIONS_PATH}")

        context = ActiveRecord::MigrationContext.new(MIGRATIONS_PATH)
        context.migrate

        CloverSandboxSimulator.logger.info("Migrations complete")
      end

      # Seed the database with realistic Clover data using FactoryBot.
      #
      # Factories pull from the existing JSON data files to produce
      # records that mirror what the Clover API returns.
      #
      # @param business_type [Symbol, String, nil] Optional business type
      #   (e.g. :restaurant, :retail). Defaults to the configured type.
      # @return [void]
      #
      # @note Seeding logic will be implemented once ActiveRecord models and
      #   factories are defined in follow-up tickets. Currently loads factory
      #   definitions only.
      # TODO: Implement actual record creation once models exist (see TOS project backlog)
      def seed!(business_type: nil)
        ensure_connected!

        require "factory_bot"

        business_type ||= CloverSandboxSimulator.configuration.business_type

        CloverSandboxSimulator.logger.info("Seeding database (business_type: #{business_type})")

        # Load factory definitions if not already loaded
        load_factories!

        # TODO: Create records using FactoryBot once models are defined:
        #   - Merchants, Categories, Items, ModifierGroups
        #   - Tax rates, Discounts, Tenders
        #   - Orders with line items and payments

        CloverSandboxSimulator.logger.info("Seeding complete (factory definitions loaded)")
      end

      # Check whether a database connection is established and usable.
      #
      # Safe to call at any time — returns false rather than raising
      # so callers can decide to fall back to JSON files.
      #
      # @return [Boolean]
      def connected?
        ActiveRecord::Base.connection_pool.with_connection do |conn|
          conn.active?
        end
      rescue StandardError
        false
      end

      # Disconnect from the database and clean up the connection pool.
      #
      # @return [void]
      def disconnect!
        ActiveRecord::Base.connection_pool.disconnect!
        CloverSandboxSimulator.logger.info("Database disconnected")
      end

      # Build the test database URL.
      #
      # @param base_url [String, nil] Base URL to derive test URL from.
      #   If nil, reads DATABASE_URL from .env.json and swaps the DB name.
      # @return [String] PostgreSQL URL pointing to the test database
      def test_database_url(base_url: nil)
        url = base_url || Configuration.database_url_from_file
        return "postgres://localhost:5432/#{TEST_DATABASE}" if url.nil?

        # Replace the database name in the URL with the test database name
        uri = URI.parse(url)
        uri.path = "/#{TEST_DATABASE}"
        uri.to_s
      rescue URI::InvalidURIError
        "postgres://localhost:5432/#{TEST_DATABASE}"
      end

      private

      # Raise if no database connection has been established yet.
      #
      # @raise [CloverSandboxSimulator::Error] when not connected
      def ensure_connected!
        return if connected?

        raise CloverSandboxSimulator::Error,
              "Database not connected. Call Database.connect!(url) first."
      end

      # Load FactoryBot factory definitions from the factories directory.
      # Guarded against repeated calls to avoid "Factory already registered" errors.
      #
      # @return [void]
      def load_factories!
        return if @factories_loaded

        factories_path = File.expand_path("db/factories", __dir__)
        FactoryBot.definition_file_paths = [factories_path] if Dir.exist?(factories_path)
        FactoryBot.find_definitions
        @factories_loaded = true
      rescue StandardError => e
        CloverSandboxSimulator.logger.warn("Could not load factories: #{e.message}")
      end

      # Strip credentials from a database URL for safe logging.
      #
      # @param url [String]
      # @return [String]
      def sanitize_url(url)
        uri = URI.parse(url)
        uri.user = "***" if uri.user
        uri.password = "***" if uri.password
        uri.to_s
      rescue URI::InvalidURIError
        url.gsub(%r{://[^@]+@}, "://***:***@")
      end
    end
  end
end
