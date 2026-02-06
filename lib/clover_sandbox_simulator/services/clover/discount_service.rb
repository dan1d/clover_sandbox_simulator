# frozen_string_literal: true

module CloverSandboxSimulator
  module Services
    module Clover
      # Manages Clover discounts with enhanced functionality for line-items,
      # promo codes, combos, time-based, and loyalty discounts
      class DiscountService < BaseService
        # Time-based discount periods
        TIME_PERIODS = {
          happy_hour: { start_hour: 15, end_hour: 18, name: "Happy Hour" },
          lunch: { start_hour: 11, end_hour: 14, name: "Lunch" },
          early_bird: { start_hour: 0, end_hour: 18, name: "Early Bird" }
        }.freeze

        # Loyalty tier thresholds
        LOYALTY_TIERS = {
          platinum: { min_visits: 50, percentage: 20 },
          gold: { min_visits: 25, percentage: 15 },
          silver: { min_visits: 10, percentage: 10 },
          bronze: { min_visits: 5, percentage: 5 }
        }.freeze

        # Cache configuration
        CACHE_TTL_SECONDS = 300 # 5 minutes for file-based caches

        # Clear all cached data
        def clear_cache
          @discount_definitions = nil
          @coupon_codes = nil
          @combos = nil
          @cache_loaded_at = nil
          logger.debug "Discount service cache cleared"
        end

        # Reload cache if TTL expired
        def refresh_cache_if_needed
          return unless cache_expired?

          clear_cache
          logger.debug "Discount service cache refreshed (TTL expired)"
        end

        # Check if cache is expired
        def cache_expired?
          return true if @cache_loaded_at.nil?

          (Time.now - @cache_loaded_at) > CACHE_TTL_SECONDS
        end

        # Fetch all discounts
        def get_discounts
          logger.info "Fetching discounts..."
          response = request(:get, endpoint("discounts"))
          elements = response&.dig("elements") || []
          logger.info "Found #{elements.size} discounts"
          elements
        end

        # Get a specific discount
        def get_discount(discount_id)
          request(:get, endpoint("discounts/#{discount_id}"))
        end

        # Create a fixed amount discount
        def create_fixed_discount(name:, amount:)
          logger.info "Creating fixed discount: #{name} ($#{amount / 100.0})"

          request(:post, endpoint("discounts"), payload: {
            "name" => name,
            "amount" => -amount.abs # Clover expects negative for discounts
          })
        end

        # Create a percentage discount
        def create_percentage_discount(name:, percentage:)
          logger.info "Creating percentage discount: #{name} (#{percentage}%)"

          request(:post, endpoint("discounts"), payload: {
            "name" => name,
            "percentage" => percentage
          })
        end

        # Delete a discount
        def delete_discount(discount_id)
          logger.info "Deleting discount: #{discount_id}"
          request(:delete, endpoint("discounts/#{discount_id}"))
        end

        # Select a random discount (30% chance of returning nil)
        def random_discount
          return nil if rand < 0.7 # 70% chance of no discount

          discounts = get_discounts
          discounts.sample
        end

        # ============================================
        # LINE-ITEM DISCOUNT METHODS
        # ============================================

        # Apply discount to a specific line item
        # Uses Clover's line item discount API
        # @param item_price [Integer] Item price in cents (required for percentage discounts)
        def apply_line_item_discount(order_id, line_item_id:, discount_id: nil, name: nil, percentage: nil, amount: nil, item_price: nil)
          logger.info "Applying line item discount to order #{order_id}, line item #{line_item_id}"

          payload = build_discount_payload(
            discount_id: discount_id,
            name: name,
            percentage: percentage,
            amount: amount,
            item_price: item_price
          )

          return nil if payload.empty?

          request(
            :post,
            endpoint("orders/#{order_id}/line_items/#{line_item_id}/discounts"),
            payload: payload
          )
        end

        # Apply discounts to multiple line items based on category eligibility
        def apply_category_line_item_discounts(order_id, line_items:, eligible_categories:, discount_config:)
          logger.info "Applying category-based line item discounts to order #{order_id}"

          applied_discounts = []

          line_items.each do |line_item|
            category = line_item.dig("item", "categories", "elements", 0, "name")
            next unless category && eligible_categories.include?(category)

            item_price = line_item["price"] || line_item.dig("item", "price") || 0
            result = apply_line_item_discount(
              order_id,
              line_item_id: line_item["id"],
              name: discount_config[:name],
              percentage: discount_config[:percentage],
              amount: discount_config[:amount],
              item_price: item_price
            )

            applied_discounts << result if result
          end

          applied_discounts
        end

        # Get all line item discounts for an order
        def get_line_item_discounts(order_id, line_item_id)
          response = request(:get, endpoint("orders/#{order_id}/line_items/#{line_item_id}/discounts"))
          response&.dig("elements") || []
        end

        # Delete a line item discount
        def delete_line_item_discount(order_id, line_item_id, discount_id)
          logger.info "Removing discount #{discount_id} from line item #{line_item_id}"
          request(:delete, endpoint("orders/#{order_id}/line_items/#{line_item_id}/discounts/#{discount_id}"))
        end

        # ============================================
        # PROMO/COUPON CODE METHODS
        # ============================================

        # Validate a promo code
        # @param code [String] The promo code to validate
        # @param order_total [Integer] Order total in cents
        # @param customer [Hash, nil] Customer data with visit_count, is_vip, etc.
        # @param line_items [Array, nil] Line items for category validation
        # @param current_time [Time] Time to validate against (for testing)
        # @return [Hash] Validation result with :valid, :error, :coupon keys
        def validate_promo_code(code, order_total: 0, customer: nil, line_items: nil, current_time: Time.now)
          logger.info "Validating promo code: #{code}"

          coupon = find_coupon_by_code(code)

          return validation_error("Invalid promo code") unless coupon
          return validation_error("Promo code is inactive") unless coupon["active"]

          # Check expiration
          valid_from = Time.parse(coupon["valid_from"])
          valid_until = Time.parse(coupon["valid_until"])
          return validation_error("Promo code has expired") if current_time > valid_until
          return validation_error("Promo code is not yet valid") if current_time < valid_from

          # Check usage limits
          if coupon["usage_limit"] && coupon["usage_count"] >= coupon["usage_limit"]
            return validation_error("Promo code has reached its usage limit")
          end

          # Check minimum order amount
          if coupon["min_order_amount"] && order_total < coupon["min_order_amount"]
            min_amount = format_currency(coupon["min_order_amount"])
            return validation_error("Minimum order amount of #{min_amount} required")
          end

          # Check customer restrictions
          if coupon["new_customers_only"] && customer && customer_visit_count(customer) > 0
            return validation_error("Promo code is for new customers only")
          end

          if coupon["vip_only"] && (!customer || !customer["is_vip"])
            return validation_error("Promo code is for VIP members only")
          end

          if coupon["birthday_required"] && (!customer || !customer_has_birthday_today?(customer))
            return validation_error("Promo code requires birthday verification")
          end

          # Check time restrictions
          if coupon["time_restricted"]
            unless within_time_period?(coupon["time_rules"], current_time)
              return validation_error("Promo code is only valid during specific hours")
            end
          end

          # Check day restrictions
          if coupon["day_restricted"]
            unless coupon["valid_days"].include?(current_time.wday)
              return validation_error("Promo code is not valid today")
            end
          end

          # Check category restrictions if line items provided
          if line_items && coupon["applicable_categories"]
            applicable = find_applicable_items(line_items, coupon["applicable_categories"])
            if applicable.empty?
              return validation_error("No eligible items for this promo code")
            end
          end

          {
            valid: true,
            coupon: coupon,
            discount_preview: calculate_coupon_discount(coupon, order_total, line_items)
          }
        end

        # Apply a validated promo code to an order
        # @param order_id [String] The order ID
        # @param code [String] The validated promo code
        # @param order_total [Integer] Order total in cents
        # @param line_items [Array, nil] Line items for category-specific discounts
        # @return [Hash, nil] Applied discount or nil if failed
        def apply_promo_code(order_id, code:, order_total: 0, line_items: nil, customer: nil, current_time: Time.now)
          validation = validate_promo_code(
            code,
            order_total: order_total,
            customer: customer,
            line_items: line_items,
            current_time: current_time
          )

          unless validation[:valid]
            logger.warn "Promo code validation failed: #{validation[:error]}"
            return nil
          end

          coupon = validation[:coupon]
          logger.info "Applying promo code #{code} to order #{order_id}"

          # Apply to specific line items if category-restricted
          if coupon["applicable_categories"] && line_items
            apply_promo_to_line_items(order_id, coupon, line_items)
          else
            apply_promo_to_order(order_id, coupon, order_total)
          end
        end

        # Get all available coupon codes
        def get_coupon_codes
          load_coupon_codes
        end

        # ============================================
        # COMBO/BUNDLE DISCOUNT METHODS
        # ============================================

        # Detect applicable combos for order items
        # @param line_items [Array] Line items with category information
        # @param current_time [Time] Time for time-restricted combos
        # @return [Array<Hash>] List of applicable combos with discount info
        def detect_combos(line_items, current_time: Time.now)
          logger.info "Detecting combo deals for #{line_items.size} items"

          combos = load_combos
          applicable_combos = []

          combos.each do |combo|
            next unless combo["active"]

            # Check time restrictions
            if combo["time_restricted"]
              next unless within_time_period?(combo["time_rules"], current_time)
            end

            # Check day restrictions
            if combo["day_restricted"]
              next unless combo["valid_days"].include?(current_time.wday)
            end

            # Check if items satisfy combo requirements
            if combo_requirements_met?(combo, line_items)
              applicable_combos << {
                combo: combo,
                matching_items: find_combo_items(combo, line_items),
                discount: calculate_combo_discount(combo, line_items)
              }
            end
          end

          # Sort by discount value (best deals first)
          applicable_combos.sort_by { |c| -c[:discount][:amount] }
        end

        # Apply a combo discount to an order
        # @param order_id [String] The order ID
        # @param combo [Hash] The combo configuration
        # @param line_items [Array] Order line items
        # @return [Hash, nil] Applied discount
        def apply_combo_discount(order_id, combo:, line_items:)
          logger.info "Applying combo '#{combo['name']}' to order #{order_id}"

          discount_info = calculate_combo_discount(combo, line_items)

          if combo["applies_to"] == "matching_items" || combo["applies_to"] == "cheapest_items"
            # Apply to specific line items
            matching = find_combo_items(combo, line_items)
            apply_discount_to_items(order_id, matching, combo, discount_info)
          else
            # Apply to order total
            apply_order_discount(order_id, combo["name"], discount_info)
          end
        end

        # Get all available combos
        def get_combos
          load_combos
        end

        # ============================================
        # TIME-BASED DISCOUNT METHODS
        # ============================================

        # Get applicable time-based discounts for current time
        # @param current_time [Time] Time to check against
        # @return [Array<Hash>] Applicable time-based discounts
        def get_time_based_discounts(current_time: Time.now)
          discounts = load_discount_definitions
          hour = current_time.hour

          discounts.select do |discount|
            next false unless discount["type"] == "time_based" || discount["type"] == "line_item_time_based"
            next false unless discount["auto_apply"]

            rules = discount["time_rules"]
            hour >= rules["start_hour"] && hour < rules["end_hour"]
          end
        end

        # Check if current time is within a specific period
        def within_time_period?(time_rules, current_time = Time.now)
          return true unless time_rules

          hour = current_time.hour
          hour >= time_rules["start_hour"] && hour < time_rules["end_hour"]
        end

        # Determine current meal period
        def current_meal_period(current_time = Time.now)
          hour = current_time.hour

          case hour
          when 7..10 then :breakfast
          when 11..14 then :lunch
          when 15..17 then :happy_hour
          when 17..21 then :dinner
          when 21..23 then :late_night
          else :closed
          end
        end

        # Get happy hour discounts if applicable
        def happy_hour_discounts(current_time: Time.now)
          hour = current_time.hour
          happy_hour_config = TIME_PERIODS[:happy_hour]
          return [] unless hour >= happy_hour_config[:start_hour] && hour < happy_hour_config[:end_hour]

          discounts = load_discount_definitions
          discounts.select do |d|
            d["id"]&.include?("happy") || d["name"]&.downcase&.include?("happy")
          end
        end

        # ============================================
        # LOYALTY DISCOUNT METHODS
        # ============================================

        # Determine loyalty tier for a customer
        # @param customer [Hash] Customer with visit_count or metadata
        # @return [Hash, nil] Loyalty tier info or nil
        def loyalty_tier(customer)
          return nil unless customer

          visit_count = customer_visit_count(customer)

          LOYALTY_TIERS.each do |tier, config|
            if visit_count >= config[:min_visits]
              return {
                tier: tier,
                percentage: config[:percentage],
                min_visits: config[:min_visits],
                visit_count: visit_count
              }
            end
          end

          nil # No tier reached
        end

        # Get applicable loyalty discount for a customer
        # @param customer [Hash] Customer data
        # @return [Hash, nil] Loyalty discount config or nil
        def get_loyalty_discount(customer)
          tier_info = loyalty_tier(customer)
          return nil unless tier_info

          discounts = load_discount_definitions
          loyalty_discounts = discounts.select { |d| d["type"] == "loyalty" }

          # Find the matching loyalty discount
          loyalty_discounts.find do |d|
            d["min_visits"] == tier_info[:min_visits]
          end
        end

        # Apply loyalty discount to an order
        # Always sends calculated amount to avoid Clover's percentage-only zero-amount bug
        def apply_loyalty_discount(order_id, customer:, order_total: nil)
          discount = get_loyalty_discount(customer)
          return nil unless discount

          logger.info "Applying loyalty discount '#{discount['name']}' to order #{order_id}"

          # Fetch order total if not provided, so we can calculate the amount
          order_total ||= OrderService.new(config: config).calculate_total(order_id)
          calculated_amount = (order_total * discount["percentage"] / 100.0).round

          logger.info "Loyalty discount: #{discount['percentage']}% of #{order_total} = #{calculated_amount}"

          request(:post, endpoint("orders/#{order_id}/discounts"), payload: {
            "name" => discount["name"],
            "amount" => -calculated_amount.abs
          })
        end

        # Check if customer qualifies for first-order discount
        def first_order_discount?(customer)
          return true unless customer

          customer_visit_count(customer) <= 1
        end

        # ============================================
        # SMART DISCOUNT SELECTION
        # ============================================

        # Select the best applicable discount for an order
        # Considers time-based, loyalty, combos, and thresholds
        # @param order_total [Integer] Order total in cents
        # @param line_items [Array] Line items with categories
        # @param customer [Hash, nil] Customer data
        # @param current_time [Time] Current time
        # @return [Hash] Best discount recommendation
        def select_best_discount(order_total:, line_items: [], customer: nil, current_time: Time.now)
          candidates = []

          # Check time-based discounts
          time_discounts = get_time_based_discounts(current_time: current_time)
          time_discounts.each do |d|
            candidates << {
              type: :time_based,
              discount: d,
              value: calculate_discount_value(d, order_total),
              priority: 2
            }
          end

          # Check loyalty discounts
          if customer
            loyalty = get_loyalty_discount(customer)
            if loyalty
              candidates << {
                type: :loyalty,
                discount: loyalty,
                value: (order_total * loyalty["percentage"] / 100.0).round,
                priority: 3
              }
            end
          end

          # Check combos
          unless line_items.empty?
            combos = detect_combos(line_items, current_time: current_time)
            combos.each do |combo_match|
              candidates << {
                type: :combo,
                discount: combo_match[:combo],
                value: combo_match[:discount][:amount],
                matching_items: combo_match[:matching_items],
                priority: 1
              }
            end
          end

          # Check threshold discounts
          threshold_discounts = load_discount_definitions.select do |d|
            d["type"] == "threshold" && d["min_order_amount"] && order_total >= d["min_order_amount"]
          end

          threshold_discounts.each do |d|
            candidates << {
              type: :threshold,
              discount: d,
              value: d["amount"] || (order_total * d["percentage"] / 100.0).round,
              priority: 4
            }
          end

          return nil if candidates.empty?

          # Sort by value (highest discount first), then by priority
          candidates.sort_by { |c| [-c[:value], c[:priority]] }.first
        end

        # Load discount definitions from JSON (with TTL)
        def load_discount_definitions
          refresh_cache_if_needed

          @discount_definitions ||= begin
            @cache_loaded_at = Time.now
            path = File.join(data_path, "discounts.json")
            return [] unless File.exist?(path)

            data = JSON.parse(File.read(path))
            data["discounts"] || []
          end
        end

        # ============================================
        # PRIVATE HELPER METHODS
        # ============================================

        private

        # Build discount payload for line item discounts
        # IMPORTANT: For percentage discounts, we need the item_price to calculate
        # the actual amount. Clover returns amount=0 for percentage discounts.
        #
        # SAFETY NET: Will raise ArgumentError if a percentage-only discount
        # (without calculated amount) would be sent, because Clover stores
        # amount=0 for these when fetched via the expand API.
        def build_discount_payload(discount_id: nil, name: nil, percentage: nil, amount: nil, item_price: nil)
          if discount_id
            discount = get_discount(discount_id)
            return {} unless discount

            payload = { "name" => discount["name"] }
            if discount["amount"]
              payload["amount"] = discount["amount"]
            elsif discount["percentage"]
              # Calculate actual amount for percentage discounts
              if item_price
                calculated = (item_price * discount["percentage"] / 100.0).round
                payload["amount"] = -calculated.abs
              else
                raise ArgumentError,
                  "Cannot send percentage-only discount to Clover API " \
                  "(amount will be 0 when fetched via expand). " \
                  "Provide item_price for line-item discounts or use order-level amount."
              end
            end
            payload
          else
            payload = {}
            payload["name"] = name if name
            if amount
              payload["amount"] = -amount.abs
            elsif percentage && item_price
              # Calculate actual amount for percentage discounts
              calculated = (item_price * percentage / 100.0).round
              payload["amount"] = -calculated.abs
            elsif percentage
              raise ArgumentError,
                "Cannot send percentage-only discount to Clover API " \
                "(amount will be 0 when fetched via expand). " \
                "Provide item_price for line-item discounts or use order-level amount."
            end
            payload
          end
        end

        def load_coupon_codes
          refresh_cache_if_needed

          @coupon_codes ||= begin
            @cache_loaded_at ||= Time.now
            path = File.join(data_path, "coupon_codes.json")
            return [] unless File.exist?(path)

            data = JSON.parse(File.read(path))
            data["coupon_codes"] || []
          end
        end

        def load_combos
          refresh_cache_if_needed

          @combos ||= begin
            @cache_loaded_at ||= Time.now
            path = File.join(data_path, "combos.json")
            return [] unless File.exist?(path)

            data = JSON.parse(File.read(path))
            data["combos"] || []
          end
        end

        def data_path
          business_type = config.business_type || :restaurant
          File.join(CloverSandboxSimulator.root, "lib", "clover_sandbox_simulator", "data", business_type.to_s)
        end

        def find_coupon_by_code(code)
          coupons = load_coupon_codes
          coupons.find { |c| c["code"].upcase == code.upcase }
        end

        def validation_error(message)
          { valid: false, error: message }
        end

        def format_currency(cents)
          "$#{'%.2f' % (cents / 100.0)}"
        end

        def customer_visit_count(customer)
          customer["visit_count"] || customer.dig("metadata", "visit_count") || 0
        end

        def customer_has_birthday_today?(customer)
          return false unless customer["birthday"]

          birthday = Date.parse(customer["birthday"]) rescue nil
          return false unless birthday

          today = Date.today
          birthday.month == today.month && birthday.day == today.day
        end

        def find_applicable_items(line_items, categories)
          line_items.select do |item|
            category = item.dig("item", "categories", "elements", 0, "name") ||
                       item.dig("item", "category")
            categories.include?(category)
          end
        end

        def calculate_coupon_discount(coupon, order_total, line_items)
          if coupon["applicable_categories"] && line_items
            # Calculate discount on applicable items only
            applicable = find_applicable_items(line_items, coupon["applicable_categories"])
            applicable_total = applicable.sum do |item|
              (item["price"] || item.dig("item", "price") || 0) * (item["quantity"] || 1)
            end

            base_amount = if coupon["discount_type"] == "percentage"
              (applicable_total * coupon["discount_value"] / 100.0).round
            else
              coupon["discount_value"]
            end
          else
            base_amount = if coupon["discount_type"] == "percentage"
              (order_total * coupon["discount_value"] / 100.0).round
            else
              coupon["discount_value"]
            end
          end

          # Apply max discount cap
          if coupon["max_discount_amount"]
            base_amount = [base_amount, coupon["max_discount_amount"]].min
          end

          {
            amount: base_amount,
            formatted: format_currency(base_amount)
          }
        end

        def apply_promo_to_line_items(order_id, coupon, line_items)
          applicable = find_applicable_items(line_items, coupon["applicable_categories"])
          applied = []

          applicable.each do |item|
            item_price = item["price"] || item.dig("item", "price") || 0
            result = if coupon["discount_type"] == "percentage"
              apply_line_item_discount(
                order_id,
                line_item_id: item["id"],
                name: coupon["name"],
                percentage: coupon["discount_value"],
                item_price: item_price
              )
            else
              apply_line_item_discount(
                order_id,
                line_item_id: item["id"],
                name: coupon["name"],
                amount: coupon["discount_value"]
              )
            end
            applied << result if result
          end

          applied
        end

        def apply_promo_to_order(order_id, coupon, order_total)
          discount_info = calculate_coupon_discount(coupon, order_total, nil)

          payload = { "name" => coupon["name"] }

          # Always send calculated amount, never percentage-only
          # Clover stores amount=0 for percentage-only discounts when fetched via expand API
          payload["amount"] = -discount_info[:amount].abs

          request(:post, endpoint("orders/#{order_id}/discounts"), payload: payload)
        end

        def combo_requirements_met?(combo, line_items)
          required_components = combo["required_components"] || []
          return false if required_components.empty?

          required_components.all? do |component|
            matching_count = count_matching_items(component, line_items)
            matching_count >= component["quantity"]
          end
        end

        def count_matching_items(component, line_items)
          line_items.count do |item|
            item_matches_component?(item, component)
          end
        end

        def item_matches_component?(item, component)
          if component["category"]
            category = item.dig("item", "categories", "elements", 0, "name") ||
                       item.dig("item", "category") ||
                       item["category"]
            return category == component["category"]
          end

          if component["items"]
            item_name = item.dig("item", "name") || item["name"]
            return component["items"].include?(item_name)
          end

          false
        end

        def find_combo_items(combo, line_items)
          matching = []
          required_components = combo["required_components"] || []

          required_components.each do |component|
            needed = component["quantity"]
            line_items.each do |item|
              next if matching.include?(item)
              next unless item_matches_component?(item, component)

              matching << item
              needed -= 1
              break if needed <= 0
            end
          end

          matching
        end

        def calculate_combo_discount(combo, line_items)
          matching = find_combo_items(combo, line_items)

          case combo["applies_to"]
          when "matching_items"
            items_total = matching.sum do |item|
              (item["price"] || item.dig("item", "price") || 0) * (item["quantity"] || 1)
            end
            base_amount = if combo["discount_type"] == "percentage"
              (items_total * combo["discount_value"] / 100.0).round
            else
              combo["discount_value"]
            end
          when "cheapest_items"
            sorted = matching.sort_by { |i| i["price"] || i.dig("item", "price") || 0 }
            max_items = combo["max_items_discounted"] || sorted.size
            cheapest = sorted.take(max_items)
            cheapest_total = cheapest.sum do |item|
              (item["price"] || item.dig("item", "price") || 0) * (item["quantity"] || 1)
            end
            base_amount = if combo["discount_type"] == "percentage"
              (cheapest_total * combo["discount_value"] / 100.0).round
            else
              [combo["discount_value"], cheapest_total].min
            end
          else # "total"
            order_total = line_items.sum do |item|
              (item["price"] || item.dig("item", "price") || 0) * (item["quantity"] || 1)
            end
            base_amount = if combo["discount_type"] == "percentage"
              (order_total * combo["discount_value"] / 100.0).round
            else
              combo["discount_value"]
            end
          end

          # Apply max cap
          if combo["max_discount_amount"]
            base_amount = [base_amount, combo["max_discount_amount"]].min
          end

          {
            amount: base_amount,
            formatted: format_currency(base_amount),
            discount_type: combo["discount_type"],
            discount_value: combo["discount_value"]
          }
        end

        def apply_discount_to_items(order_id, items, combo, discount_info)
          applied = []

          items.each do |item|
            item_price = item["price"] || item.dig("item", "price") || 0
            result = if combo["discount_type"] == "percentage"
              apply_line_item_discount(
                order_id,
                line_item_id: item["id"],
                name: combo["name"],
                percentage: combo["discount_value"],
                item_price: item_price
              )
            else
              per_item_amount = discount_info[:amount] / items.size
              apply_line_item_discount(
                order_id,
                line_item_id: item["id"],
                name: combo["name"],
                amount: per_item_amount
              )
            end
            applied << result if result
          end

          applied
        end

        def apply_order_discount(order_id, name, discount_info)
          request(:post, endpoint("orders/#{order_id}/discounts"), payload: {
            "name" => name,
            "amount" => -discount_info[:amount]
          })
        end

        def calculate_discount_value(discount, order_total)
          if discount["percentage"]
            (order_total * discount["percentage"] / 100.0).round
          elsif discount["amount"]
            discount["amount"].abs
          else
            0
          end
        end
      end
    end
  end
end
