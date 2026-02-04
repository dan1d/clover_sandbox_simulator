# frozen_string_literal: true

module CloverSandboxSimulator
  module Services
    module Clover
      # Manages Clover tax rates and item-tax associations
      class TaxService < BaseService
        # Default tax rates for restaurants
        DEFAULT_TAX_RATES = [
          { name: "Sales Tax", rate: 8.25, is_default: true, description: "Standard sales tax" },
          { name: "Alcohol Tax", rate: 10.0, is_default: false, description: "Additional tax on alcoholic beverages" },
          { name: "Prepared Food Tax", rate: 8.25, is_default: false, description: "Tax on prepared food items" }
        ].freeze

        # Fetch all tax rates
        def get_tax_rates
          logger.info "Fetching tax rates..."
          response = request(:get, endpoint("tax_rates"))
          elements = response&.dig("elements") || []
          logger.info "Found #{elements.size} tax rates"
          elements
        end

        # Get default tax rate
        def default_tax_rate
          rates = get_tax_rates
          # Find default rate or return first active one
          rates.find { |r| r["isDefault"] == true } || rates.first
        end

        # Create a tax rate
        def create_tax_rate(name:, rate:, is_default: false)
          logger.info "Creating tax rate: #{name} (#{rate}%)"

          # Rate is stored as basis points (8.25% = 825000)
          rate_basis_points = (rate * 100_000).to_i

          request(:post, endpoint("tax_rates"), payload: {
            "name" => name,
            "rate" => rate_basis_points,
            "isDefault" => is_default,
            "taxType" => "VAT_EXEMPT" # For US sales tax
          })
        end

        # Delete a tax rate
        def delete_tax_rate(tax_rate_id)
          logger.info "Deleting tax rate: #{tax_rate_id}"
          request(:delete, endpoint("tax_rates/#{tax_rate_id}"))
        end

        # Calculate tax for an amount using a flat rate
        def calculate_tax(subtotal, tax_rate = nil)
          rate = tax_rate || config.tax_rate
          (subtotal * rate / 100.0).round
        end

        # ========== Item-Tax Rate Association Methods ==========

        # Get all items associated with a specific tax rate
        def get_items_for_tax_rate(tax_rate_id)
          logger.info "Fetching items for tax rate: #{tax_rate_id}"
          response = request(:get, endpoint("tax_rates/#{tax_rate_id}/items"))
          elements = response&.dig("elements") || []
          logger.info "Found #{elements.size} items for tax rate"
          elements
        end

        # Get all tax rates associated with a specific item
        # @note This endpoint may not be available in sandbox environments
        def get_tax_rates_for_item(item_id)
          logger.debug "Fetching tax rates for item: #{item_id}"
          begin
            response = request(:get, endpoint("items/#{item_id}/tax_rates"))
            response&.dig("elements") || []
          rescue ApiError => e
            if e.message.include?("405")
              logger.debug "Getting item tax rates not supported in this environment"
              []
            else
              raise
            end
          end
        end

        # Associate an item with a tax rate
        def associate_item_with_tax_rate(item_id, tax_rate_id)
          logger.info "Associating item #{item_id} with tax rate #{tax_rate_id}"
          request(:post, endpoint("tax_rate_items"), payload: {
            "elements" => [
              { "item" => { "id" => item_id }, "taxRate" => { "id" => tax_rate_id } }
            ]
          })
        end

        # Remove an item from a tax rate
        def remove_item_from_tax_rate(item_id, tax_rate_id)
          logger.info "Removing item #{item_id} from tax rate #{tax_rate_id}"
          request(:delete, endpoint("tax_rate_items"), params: { item: item_id, taxRate: tax_rate_id })
        end

        # Associate multiple items with a tax rate
        def associate_items_with_tax_rate(item_ids, tax_rate_id)
          logger.info "Associating #{item_ids.size} items with tax rate #{tax_rate_id}"
          elements = item_ids.map do |item_id|
            { "item" => { "id" => item_id }, "taxRate" => { "id" => tax_rate_id } }
          end
          request(:post, endpoint("tax_rate_items"), payload: { "elements" => elements })
        end

        # ========== Per-Item Tax Calculation ==========

        # Calculate tax for a specific item based on its assigned tax rates
        # @param item_id [String] The item ID
        # @param amount [Integer] The amount in cents
        # @return [Integer] The total tax in cents
        def calculate_item_tax(item_id, amount)
          rates = get_tax_rates_for_item(item_id)
          return 0 if rates.empty?

          # Sum up all applicable tax rates (convert from basis points to percentage)
          total_rate_percentage = rates.sum { |r| (r["rate"] || 0) / 100_000.0 }

          (amount * total_rate_percentage / 100.0).round
        end

        # Cache configuration
        CACHE_TTL_SECONDS = 300 # 5 minutes
        CACHE_MAX_SIZE = 1000   # Maximum cached items

        # Calculate tax for multiple items with bounded caching
        # @param items [Array<Hash>] Array of { item_id:, amount: }
        # @return [Integer] The total tax in cents
        def calculate_items_tax(items)
          items.sum do |item|
            item_id = item[:item_id]
            amount = item[:amount]

            rates = get_cached_tax_rates(item_id)
            total_rate = rates.sum { |r| (r["rate"] || 0) / 100_000.0 }
            (amount * total_rate / 100.0).round
          end
        end

        # Clear the tax rates cache
        def clear_cache
          @item_tax_rates_cache = {}
          @cache_timestamps = {}
        end

        # Get tax rates from cache or API with TTL and size limits
        def get_cached_tax_rates(item_id)
          @item_tax_rates_cache ||= {}
          @cache_timestamps ||= {}

          now = Time.now.to_i

          # Check if cached and not expired
          if @item_tax_rates_cache.key?(item_id)
            if now - @cache_timestamps[item_id] < CACHE_TTL_SECONDS
              return @item_tax_rates_cache[item_id]
            else
              # Expired - remove from cache
              @item_tax_rates_cache.delete(item_id)
              @cache_timestamps.delete(item_id)
            end
          end

          # Prune cache if too large (LRU-style: remove oldest entries)
          if @item_tax_rates_cache.size >= CACHE_MAX_SIZE
            prune_cache(CACHE_MAX_SIZE / 2)
          end

          # Fetch and cache
          rates = get_tax_rates_for_item(item_id)
          @item_tax_rates_cache[item_id] = rates
          @cache_timestamps[item_id] = now
          rates
        end

        # Remove oldest cache entries
        def prune_cache(keep_count)
          return if @cache_timestamps.empty?

          # Sort by timestamp and keep only the newest entries
          sorted_keys = @cache_timestamps.sort_by { |_, ts| ts }.map(&:first)
          keys_to_remove = sorted_keys.take(sorted_keys.size - keep_count)

          keys_to_remove.each do |key|
            @item_tax_rates_cache.delete(key)
            @cache_timestamps.delete(key)
          end

          logger.debug "Pruned #{keys_to_remove.size} expired cache entries"
        end

        # ========== Tax Rate Setup ==========

        # Set up default tax rates for a restaurant if they don't exist
        def setup_default_tax_rates
          logger.info "Setting up default tax rates..."
          existing = get_tax_rates
          existing_names = existing.map { |r| r["name"]&.downcase }

          created = []
          DEFAULT_TAX_RATES.each do |rate_data|
            if existing_names.include?(rate_data[:name].downcase)
              logger.debug "Tax rate '#{rate_data[:name]}' already exists, skipping"
              created << existing.find { |r| r["name"]&.downcase == rate_data[:name].downcase }
            else
              rate = create_tax_rate(
                name: rate_data[:name],
                rate: rate_data[:rate],
                is_default: rate_data[:is_default]
              )
              created << rate if rate
            end
          end

          logger.info "Tax rates ready: #{created.size}"
          created
        end

        # Assign tax rates to items based on their category
        # @param items [Array<Hash>] Items with category information
        # @param tax_rates [Array<Hash>] Available tax rates
        # @param category_tax_mapping [Hash] Mapping of category names to tax rate names
        def assign_taxes_by_category(items, tax_rates, category_tax_mapping = nil)
          category_tax_mapping ||= default_category_tax_mapping

          # Build a lookup for tax rates by name
          tax_rate_lookup = tax_rates.each_with_object({}) do |rate, hash|
            hash[rate["name"]&.downcase] = rate["id"]
          end

          items.each do |item|
            category = item.dig("categories", "elements", 0, "name") || item["category"]
            next unless category

            # Find applicable tax rates for this category
            applicable_taxes = category_tax_mapping[category] || category_tax_mapping["default"] || ["Sales Tax"]

            applicable_taxes.each do |tax_name|
              tax_rate_id = tax_rate_lookup[tax_name.downcase]
              next unless tax_rate_id

              begin
                associate_item_with_tax_rate(item["id"], tax_rate_id)
              rescue ApiError => e
                logger.debug "Could not assign tax to item #{item["id"]}: #{e.message}"
              end
            end
          end
        end

        private

        # Default mapping of categories to tax rates
        def default_category_tax_mapping
          {
            "Alcoholic Beverages" => ["Sales Tax", "Alcohol Tax"],
            "Beer" => ["Sales Tax", "Alcohol Tax"],
            "Wine" => ["Sales Tax", "Alcohol Tax"],
            "Cocktails" => ["Sales Tax", "Alcohol Tax"],
            "Appetizers" => ["Sales Tax"],
            "Entrees" => ["Sales Tax"],
            "Sides" => ["Sales Tax"],
            "Desserts" => ["Sales Tax"],
            "Drinks" => ["Sales Tax"],
            "Specials" => ["Sales Tax"],
            "default" => ["Sales Tax"]
          }
        end
      end
    end
  end
end
