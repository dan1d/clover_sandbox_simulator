# frozen_string_literal: true

require "concurrent"

module CloverSandboxSimulator
  # Executes operations across multiple merchants in parallel
  #
  # Usage:
  #   executor = ParallelExecutor.new
  #   
  #   # Run a block for each merchant
  #   results = executor.run_all do |services, merchant|
  #     charge = services.ecommerce.create_test_charge(amount: 1000)
  #     refund = services.ecommerce.create_refund(charge_id: charge["id"])
  #     { charge: charge, refund: refund }
  #   end
  #
  class ParallelExecutor
    attr_reader :logger, :merchants, :results

    def initialize(merchant_ids: nil)
      @logger = CloverSandboxSimulator.logger
      @merchants = load_merchants(merchant_ids)
      @results = {}
    end

    # Run a block for each merchant in parallel
    #
    # @param max_threads [Integer] Maximum concurrent threads (default: 5)
    # @yield [services, merchant] Block to execute for each merchant
    # @yieldparam services [ServicesManager] Services for the merchant
    # @yieldparam merchant [Hash] Merchant configuration
    # @return [Hash] Results keyed by merchant_id
    def run_all(max_threads: 5, &block)
      return {} if merchants.empty?

      logger.info "Running operations for #{merchants.size} merchants (max #{max_threads} threads)"

      pool = Concurrent::FixedThreadPool.new(max_threads)
      futures = {}

      merchants.each do |merchant|
        merchant_id = merchant[:id]

        futures[merchant_id] = Concurrent::Future.execute(executor: pool) do
          run_for_merchant(merchant, &block)
        end
      end

      # Wait for all futures to complete
      futures.each do |merchant_id, future|
        begin
          @results[merchant_id] = {
            success: true,
            merchant_name: merchants.find { |m| m[:id] == merchant_id }&.dig(:name),
            data: future.value(30) # 30 second timeout per merchant
          }
        rescue StandardError => e
          @results[merchant_id] = {
            success: false,
            merchant_name: merchants.find { |m| m[:id] == merchant_id }&.dig(:name),
            error: e.message
          }
        end
      end

      pool.shutdown
      pool.wait_for_termination(60)

      print_summary
      @results
    end

    # Run for specific merchant IDs only
    #
    # @param merchant_ids [Array<String>] List of merchant IDs
    # @yield [services, merchant] Block to execute
    # @return [Hash] Results
    def run_for(merchant_ids, &block)
      @merchants = load_merchants(merchant_ids)
      run_all(&block)
    end

    # Run Ecommerce test (charge + refund) for all merchants
    #
    # @param amount [Integer] Charge amount in cents
    # @return [Hash] Results with charge and refund details
    def test_ecommerce_all(amount: 1000)
      run_all do |services, merchant|
        next { skipped: true, reason: "Ecommerce not configured" } unless services.ecommerce_available?

        charge = services.ecommerce.create_test_charge(amount: amount)
        next { error: "Charge failed" } unless charge&.dig("id")

        refund = services.ecommerce.create_refund(charge_id: charge["id"])

        {
          charge_id: charge["id"],
          charge_amount: charge["amount"],
          refund_id: refund&.dig("id"),
          refund_amount: refund&.dig("amount")
        }
      end
    end

    # Refresh tokens for all merchants that have refresh tokens
    #
    # @return [Hash] Results with new token status
    def refresh_tokens_all
      run_all do |services, merchant|
        config = services.config

        unless config.refresh_token && !config.refresh_token.empty?
          next { skipped: true, reason: "No refresh token" }
        end

        unless config.oauth_enabled?
          next { skipped: true, reason: "OAuth not configured (need APP_ID and APP_SECRET)" }
        end

        tokens = services.oauth.refresh_current_merchant_token
        if tokens
          {
            refreshed: true,
            expires_in: tokens["expires_in"]
          }
        else
          { refreshed: false, error: "Refresh failed" }
        end
      end
    end

    # Run a full day simulation for all merchants
    # Requires valid OAuth tokens in .env.json for Platform API
    #
    # @param multiplier [Float] Order count multiplier (default 0.5 for faster runs)
    # @param refund_percentage [Integer] Percentage of orders to refund (default 10)
    # @return [Hash] Results with order counts and stats
    def run_day_all(multiplier: 0.5, refund_percentage: 10)
      run_all(max_threads: 2) do |services, merchant|
        config = services.config

        unless config.platform_enabled?
          next { skipped: true, reason: "OAuth token required (Platform API)" }
        end

        # Run full day simulation
        generator = Generators::OrderGenerator.new(
          services: services,
          refund_percentage: refund_percentage
        )

        orders = generator.generate_realistic_day(
          date: Date.today,
          multiplier: multiplier
        )

        stats = generator.stats

        {
          orders: orders.size,
          revenue: stats[:revenue],
          tips: stats[:tips],
          tax: stats[:tax],
          refunds: stats[:refunds]
        }
      end
    end

    # Run multiple card transactions with refunds for each merchant
    # Works without OAuth tokens (Ecommerce API only)
    #
    # @param transaction_count [Integer] Number of transactions per merchant
    # @param refund_percentage [Integer] Percentage of transactions to refund
    # @return [Hash] Results with transaction details
    def run_card_transactions_all(transaction_count: 5, refund_percentage: 40)
      run_all(max_threads: 3) do |services, merchant|
        next { skipped: true, reason: "Ecommerce not configured" } unless services.ecommerce_available?

        results = {
          charges: [],
          refunds: [],
          total_charged: 0,
          total_refunded: 0
        }

        # Create transactions
        transaction_count.times do |i|
          # Random amount between $5 and $75
          amount = rand(500..7500)

          # Small delay to avoid rate limits
          sleep(0.5) if i > 0

          charge = services.ecommerce.create_test_charge(amount: amount)
          next unless charge&.dig("id")

          results[:charges] << {
            id: charge["id"],
            amount: charge["amount"]
          }
          results[:total_charged] += charge["amount"]
        end

        # Refund some transactions
        refund_count = (results[:charges].size * refund_percentage / 100.0).ceil
        charges_to_refund = results[:charges].sample(refund_count)

        charges_to_refund.each_with_index do |charge, i|
          sleep(0.5) if i > 0

          # 60% full refunds, 40% partial
          if rand < 0.6
            refund = services.ecommerce.create_refund(charge_id: charge[:id])
          else
            partial_amount = (charge[:amount] * rand(25..75) / 100.0).round
            refund = services.ecommerce.create_refund(charge_id: charge[:id], amount: partial_amount)
          end

          next unless refund&.dig("id")

          results[:refunds] << {
            id: refund["id"],
            charge_id: charge[:id],
            amount: refund["amount"]
          }
          results[:total_refunded] += refund["amount"]
        end

        results
      end
    end

    private

    def load_merchants(merchant_ids = nil)
      config = Configuration.new
      all_merchants = config.available_merchants

      if merchant_ids&.any?
        all_merchants.select { |m| merchant_ids.include?(m[:id]) }
      else
        all_merchants
      end
    end

    def run_for_merchant(merchant)
      merchant_id = merchant[:id]
      merchant_name = merchant[:name]

      logger.info "[#{merchant_id}] Starting operations for #{merchant_name}"

      # Create a new configuration for this merchant
      config = Configuration.new
      config.load_merchant(merchant_id: merchant_id)

      # Create services manager for this merchant
      services = Services::Clover::ServicesManager.new(config: config)

      # Execute the block
      result = yield(services, merchant)

      logger.info "[#{merchant_id}] Completed for #{merchant_name}"
      result
    rescue StandardError => e
      logger.error "[#{merchant_id}] Error: #{e.message}"
      # Return error info instead of raising
      { error: true, message: e.message }
    end

    def print_summary
      logger.info "\n" + "=" * 60
      logger.info "PARALLEL EXECUTION SUMMARY"
      logger.info "=" * 60

      success_count = @results.count { |_, r| r[:success] }
      fail_count = @results.count { |_, r| !r[:success] }

      @results.each do |merchant_id, result|
        status = result[:success] ? "✓" : "✗"
        name = result[:merchant_name] || merchant_id

        if result[:success]
          data = result[:data]
          if data.nil?
            logger.info "  #{status} #{name}: Completed (no data returned)"
          elsif data.is_a?(Hash)
            if data[:error]
              logger.info "  ✗ #{name}: ERROR - #{data[:message]}"
            elsif data[:skipped]
              logger.info "  #{status} #{name}: Skipped - #{data[:reason]}"
            elsif data[:charge_id]
              # Single charge/refund test
              logger.info "  #{status} #{name}: Charge #{data[:charge_id]} ($#{(data[:charge_amount] || 0) / 100.0}), Refund #{data[:refund_id]}"
            elsif data[:charges]
              # Multiple card transactions
              logger.info "  #{status} #{name}: #{data[:charges].size} charges ($#{(data[:total_charged] || 0) / 100.0}), #{data[:refunds].size} refunds ($#{(data[:total_refunded] || 0) / 100.0})"
            elsif data[:orders]
              # Full day simulation
              logger.info "  #{status} #{name}: #{data[:orders]} orders, $#{(data[:revenue] || 0) / 100.0} revenue, #{data[:refunds]&.dig(:total) || 0} refunds"
            elsif data[:refreshed]
              logger.info "  #{status} #{name}: Token refreshed"
            else
              logger.info "  #{status} #{name}: #{data.inspect}"
            end
          else
            logger.info "  #{status} #{name}: #{data.inspect}"
          end
        else
          logger.info "  #{status} #{name}: ERROR - #{result[:error]}"
        end
      end

      logger.info "-" * 60
      logger.info "Total: #{success_count} succeeded, #{fail_count} failed"
      logger.info "=" * 60
    end
  end
end
