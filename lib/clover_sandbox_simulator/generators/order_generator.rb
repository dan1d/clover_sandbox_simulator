# frozen_string_literal: true

module CloverSandboxSimulator
  module Generators
    # Generates realistic restaurant orders and payments with enhanced discount support
    class OrderGenerator
      # Meal periods with realistic distributions
      MEAL_PERIODS = {
        breakfast: { hours: 7..10, weight: 15, avg_items: 2..4, avg_party: 1..2 },
        lunch: { hours: 11..14, weight: 30, avg_items: 2..5, avg_party: 1..4 },
        happy_hour: { hours: 15..17, weight: 10, avg_items: 2..4, avg_party: 2..4 },
        dinner: { hours: 17..21, weight: 35, avg_items: 3..6, avg_party: 2..6 },
        late_night: { hours: 21..23, weight: 10, avg_items: 2..4, avg_party: 1..3 }
      }.freeze

      # Dining option distributions by meal period
      DINING_BY_PERIOD = {
        breakfast: { "HERE" => 40, "TO_GO" => 50, "DELIVERY" => 10 },
        lunch: { "HERE" => 35, "TO_GO" => 45, "DELIVERY" => 20 },
        happy_hour: { "HERE" => 80, "TO_GO" => 15, "DELIVERY" => 5 },
        dinner: { "HERE" => 70, "TO_GO" => 15, "DELIVERY" => 15 },
        late_night: { "HERE" => 50, "TO_GO" => 30, "DELIVERY" => 20 }
      }.freeze

      # Tip percentages by dining option
      TIP_RATES = {
        "HERE" => { min: 15, max: 25 },      # Dine-in tips higher
        "TO_GO" => { min: 0, max: 15 },       # Takeout tips lower
        "DELIVERY" => { min: 10, max: 20 }    # Delivery tips moderate
      }.freeze

      # Order patterns by day of week
      ORDER_PATTERNS = {
        weekday: { min: 40, max: 60 },
        friday: { min: 70, max: 100 },
        saturday: { min: 80, max: 120 },
        sunday: { min: 50, max: 80 }
      }.freeze

      # Category preferences by meal period
      CATEGORY_PREFERENCES = {
        breakfast: ["Drinks", "Sides"],
        lunch: ["Appetizers", "Entrees", "Sides", "Drinks"],
        happy_hour: ["Appetizers", "Alcoholic Beverages", "Drinks"],
        dinner: ["Appetizers", "Entrees", "Sides", "Desserts", "Alcoholic Beverages", "Drinks"],
        late_night: ["Appetizers", "Entrees", "Alcoholic Beverages", "Desserts"]
      }.freeze

      # Discount application probabilities
      DISCOUNT_PROBABILITIES = {
        promo_code: 0.08,        # 8% use a promo code
        loyalty: 0.15,           # 15% are loyalty members
        combo: 0.12,             # 12% get combo discount
        time_based: 0.90,        # 90% of eligible get time discounts
        line_item: 0.10,         # 10% get line item discounts
        threshold: 0.20          # 20% get threshold discounts
      }.freeze

      # Gift card configuration
      GIFT_CARD_CONFIG = {
        payment_chance: 10,       # 10% of orders may use gift cards for payment
        purchase_chance: 5,       # 5% of orders may include gift card purchase
        full_payment_chance: 60   # 60% of gift card payments cover full amount
      }.freeze

      # Refund reasons
      REFUND_REASONS = %w[customer_request quality_issue wrong_order duplicate_charge].freeze

      attr_reader :services, :logger, :stats, :refund_percentage

      def initialize(services: nil, refund_percentage: 5)
        @services = services || Services::Clover::ServicesManager.new
        @logger = CloverSandboxSimulator.logger
        @refund_percentage = refund_percentage
        @stats = {
          orders: 0,
          revenue: 0,
          tips: 0,
          tax: 0,
          discounts: 0,
          by_period: {},
          by_dining: {},
          by_discount_type: {},
          gift_cards: { payments: 0, full_payments: 0, partial_payments: 0, purchases: 0, amount_redeemed: 0 },
          refunds: { total: 0, full: 0, partial: 0, amount: 0 }
        }
      end

      # Generate a realistic day of restaurant operations
      def generate_realistic_day(date: Date.today, multiplier: 1.0, simulated_time: nil)
        count = (order_count_for_date(date) * multiplier).to_i

        logger.info "=" * 60
        logger.info "Generating realistic restaurant day: #{date}"
        logger.info "    Target orders: #{count}"
        logger.info "    Day: #{date.strftime('%A')}"
        logger.info "=" * 60

        # Fetch required data
        data = fetch_required_data
        return [] unless data

        # Distribute orders across meal periods
        period_orders = distribute_orders_by_period(count)

        orders = []
        period_orders.each do |period, period_count|
          logger.info "-" * 40
          logger.info "#{period.to_s.upcase} SERVICE: #{period_count} orders"

          period_count.times do |i|
            # Generate simulated time for the order
            order_time = simulated_time || generate_order_time(date, period)

            order = create_realistic_order(
              period: period,
              data: data,
              order_num: i + 1,
              total_in_period: period_count,
              order_time: order_time
            )

            if order
              orders << order
              update_stats(order, period)
            end
          end
        end

        # Process refunds for some orders
        process_refunds(orders) if refund_percentage > 0

        print_summary
        orders
      end

      # Process refunds for a percentage of completed orders
      def process_refunds(orders)
        return if orders.empty? || refund_percentage <= 0

        refund_count = (orders.size * refund_percentage / 100.0).ceil
        refund_count = [refund_count, orders.size].min

        logger.info "-" * 40
        logger.info "PROCESSING REFUNDS: #{refund_count} orders (#{refund_percentage}%)"

        # Select random orders to refund
        orders_to_refund = orders.sample(refund_count)

        orders_to_refund.each do |order|
          process_order_refund(order)
        end
      end

      # Process a refund for a single order
      def process_order_refund(order)
        order_id = order["id"]
        payments = order.dig("payments", "elements") || []

        return if payments.empty?

        payment = payments.first
        payment_id = payment["id"]
        payment_amount = payment["amount"] || 0

        return if payment_amount <= 0

        # 60% full refunds, 40% partial refunds
        is_full_refund = rand < 0.6
        reason = REFUND_REASONS.sample

        if is_full_refund
          # Full refund
          begin
            result = services.refund.create_full_refund(payment_id: payment_id, reason: reason)
            if result
              @stats[:refunds][:total] += 1
              @stats[:refunds][:full] += 1
              @stats[:refunds][:amount] += payment_amount
              logger.info "  💸 Full refund: Order #{order_id} - $#{'%.2f' % (payment_amount / 100.0)} (#{reason})"
            end
          rescue StandardError => e
            logger.warn "  Failed to refund order #{order_id}: #{e.message}"
          end
        else
          # Partial refund (25-75% of payment)
          refund_percent = rand(25..75)
          refund_amount = (payment_amount * refund_percent / 100.0).round

          begin
            result = services.refund.create_partial_refund(
              payment_id: payment_id,
              amount: refund_amount,
              reason: reason
            )
            if result
              @stats[:refunds][:total] += 1
              @stats[:refunds][:partial] += 1
              @stats[:refunds][:amount] += refund_amount
              logger.info "  💸 Partial refund: Order #{order_id} - $#{'%.2f' % (refund_amount / 100.0)} of $#{'%.2f' % (payment_amount / 100.0)} (#{reason})"
            end
          rescue StandardError => e
            logger.warn "  Failed to partially refund order #{order_id}: #{e.message}"
          end
        end
      end

      # Generate orders for today (simple mode)
      def generate_today(count: nil)
        if count
          generate_for_date(Date.today, count: count)
        else
          generate_realistic_day
        end
      end

      # Generate specific count of orders
      def generate_for_date(date, count:)
        logger.info "=" * 60
        logger.info "Generating #{count} orders for #{date}"
        logger.info "=" * 60

        data = fetch_required_data
        return [] unless data

        orders = []
        count.times do |i|
          period = weighted_random_period
          order_time = generate_order_time(date, period)
          logger.info "-" * 40
          logger.info "Creating order #{i + 1}/#{count} (#{period})"

          order = create_realistic_order(
            period: period,
            data: data,
            order_num: i + 1,
            total_in_period: count,
            order_time: order_time
          )

          if order
            orders << order
            update_stats(order, period)
          end
        end

        # Process refunds for some orders
        process_refunds(orders) if refund_percentage > 0

        print_summary
        orders
      end

      private

      def fetch_required_data
        items = services.inventory.get_items
        employees = services.employee.get_employees
        customers = services.customer.get_customers
        tenders = services.tender.get_safe_tenders
        discounts = services.discount.get_discounts

        # Fetch gift cards for payment scenarios
        gift_cards = begin
          services.gift_card.fetch_gift_cards
        rescue StandardError => e
          logger.debug "Could not fetch gift cards: #{e.message}"
          []
        end

        # Find the gift card tender for payments
        gift_card_tender = tenders.find { |t| t["label"]&.downcase&.include?("gift") }

        if items.empty?
          logger.error "No items found! Please run setup first."
          return nil
        end

        if employees.empty?
          logger.error "No employees found! Please run setup first."
          return nil
        end

        if tenders.empty?
          logger.error "No safe tenders found!"
          return nil
        end

        # Categorize items for meal period selection
        items_by_category = items.group_by { |i| i.dig("categories", "elements", 0, "name") || "Other" }

        {
          items: items,
          items_by_category: items_by_category,
          employees: employees,
          customers: customers,
          tenders: tenders,
          discounts: discounts,
          gift_cards: gift_cards,
          gift_card_tender: gift_card_tender
        }
      end

      def distribute_orders_by_period(total_count)
        total_weight = MEAL_PERIODS.values.sum { |p| p[:weight] }

        distribution = {}
        remaining = total_count

        MEAL_PERIODS.each_with_index do |(period, config), index|
          if index == MEAL_PERIODS.size - 1
            distribution[period] = remaining
          else
            count = ((config[:weight].to_f / total_weight) * total_count).round
            distribution[period] = [count, remaining].min
            remaining -= distribution[period]
          end
        end

        distribution
      end

      def weighted_random_period
        total_weight = MEAL_PERIODS.values.sum { |p| p[:weight] }
        random = rand(total_weight)

        cumulative = 0
        MEAL_PERIODS.each do |period, config|
          cumulative += config[:weight]
          return period if random < cumulative
        end

        :dinner # fallback
      end

      def generate_order_time(date, period)
        hours = MEAL_PERIODS[period][:hours]
        hour = rand(hours)
        minute = rand(60)
        Time.new(date.year, date.month, date.day, hour, minute, 0)
      end

      def create_realistic_order(period:, data:, order_num:, total_in_period:, order_time: nil)
        order_time ||= Time.now
        config = MEAL_PERIODS[period]
        employee = data[:employees].sample

        # 60% of orders have customer info (regulars, rewards members)
        customer = data[:customers].sample if rand < 0.6

        # Simulate customer visit count for loyalty
        if customer
          customer["visit_count"] ||= rand(0..60)
          customer["is_vip"] = rand < 0.05 # 5% are VIP
        end

        # Create order shell
        order = services.order.create_order(
          employee_id: employee["id"],
          customer_id: customer&.dig("id")
        )

        return nil unless order && order["id"]

        order_id = order["id"]
        logger.info "Created order: #{order_id}"

        # Set dining option based on meal period
        dining = select_dining_option(period)
        services.order.set_dining_option(order_id, dining)
        logger.debug "  Dining: #{dining}"

        # Party size affects item count
        party_size = rand(config[:avg_party])
        base_items = rand(config[:avg_items])
        num_items = [base_items + (party_size / 2), 1].max

        # Select items appropriate for the meal period
        selected_items = select_items_for_period(period, data, num_items, party_size)

        line_items = selected_items.map do |item|
          # Quantity varies by party size
          quantity = party_size > 2 && rand < 0.3 ? rand(2..3) : 1
          note = random_note if rand < 0.15

          {
            item_id: item["id"],
            quantity: quantity,
            note: note
          }
        end

        added_line_items = services.order.add_line_items(order_id, line_items)

        # Validate that at least one line item was added
        # Payments should not be created for orders without items
        if added_line_items.empty?
          logger.warn "Order #{order_id}: No line items added, skipping payment creation"
          services.order.update_state(order_id, "open")
          return nil
        end

        # Enrich line items with category data for discount processing
        enriched_items = enrich_line_items(added_line_items, selected_items)

        # Calculate preliminary total for discount eligibility
        preliminary_total = calculate_preliminary_total(enriched_items)

        # Apply enhanced discounts
        discount_applied = apply_enhanced_discounts(
          order_id: order_id,
          line_items: enriched_items,
          order_total: preliminary_total,
          customer: customer,
          period: period,
          order_time: order_time,
          discounts: data[:discounts]
        )

        # Calculate totals
        subtotal = services.order.calculate_total(order_id)
        services.order.update_total(order_id, subtotal)

        # Calculate tax and tip (tip varies by dining option)
        tax_amount = services.tax.calculate_tax(subtotal)
        tip_amount = calculate_tip(subtotal, dining, party_size)

        # Process payment (may use gift card ~10% of the time)
        process_order_payment(
          order_id: order_id,
          subtotal: subtotal,
          tax_amount: tax_amount,
          tip_amount: tip_amount,
          employee_id: employee["id"],
          tenders: data[:tenders],
          dining: dining,
          party_size: party_size,
          gift_cards: data[:gift_cards] || [],
          gift_card_tender: data[:gift_card_tender]
        )

        # Update order state to paid
        services.order.update_state(order_id, "paid")

        # Return final order with metadata
        final_order = services.order.get_order(order_id)
        final_order["_metadata"] = {
          period: period,
          dining: dining,
          party_size: party_size,
          tip: tip_amount,
          tax: tax_amount,
          order_time: order_time,
          discount_applied: discount_applied
        }

        final_order
      end

      def enrich_line_items(added_items, selected_items)
        added_items.map.with_index do |line_item, idx|
          next line_item unless line_item

          original = selected_items[idx]
          if original && line_item["item"].nil?
            line_item["item"] = {
              "name" => original["name"],
              "price" => original["price"],
              "category" => original["category"],
              "categories" => {
                "elements" => [{ "name" => original["category"] }]
              }
            }
          end
          line_item["price"] ||= original["price"] if original
          line_item
        end.compact
      end

      def calculate_preliminary_total(line_items)
        line_items.sum do |item|
          price = item["price"] || item.dig("item", "price") || 0
          quantity = item["quantity"] || 1
          price * quantity
        end
      end

      def apply_enhanced_discounts(order_id:, line_items:, order_total:, customer:, period:, order_time:, discounts:)
        discount_service = services.discount
        applied = nil

        # 1. Check for time-based auto-apply discounts (highest priority during happy hour)
        if period == :happy_hour && rand < DISCOUNT_PROBABILITIES[:time_based]
          time_discounts = discount_service.get_time_based_discounts(current_time: order_time)
          if time_discounts.any?
            discount = time_discounts.first
            result = apply_discount_by_type(order_id, discount, order_total, line_items)
            if result
              applied = { type: :time_based, name: discount["name"], discount: discount }
              track_discount_stat(:time_based)
              logger.info "  Applied time-based discount: #{discount['name']}"
            end
          end
        end

        # 2. Check for loyalty discounts
        if !applied && customer && rand < DISCOUNT_PROBABILITIES[:loyalty]
          loyalty_discount = discount_service.get_loyalty_discount(customer)
          if loyalty_discount
            result = discount_service.apply_loyalty_discount(order_id, customer: customer)
            if result
              tier = discount_service.loyalty_tier(customer)
              applied = { type: :loyalty, name: loyalty_discount["name"], tier: tier[:tier] }
              track_discount_stat(:loyalty)
              logger.info "  Applied loyalty discount: #{loyalty_discount['name']} (#{tier[:tier]})"
            end
          end
        end

        # 3. Check for combo discounts
        if !applied && line_items.size >= 3 && rand < DISCOUNT_PROBABILITIES[:combo]
          combos = discount_service.detect_combos(line_items, current_time: order_time)
          if combos.any?
            best_combo = combos.first # Already sorted by value
            result = discount_service.apply_combo_discount(
              order_id,
              combo: best_combo[:combo],
              line_items: line_items
            )
            if result
              applied = { type: :combo, name: best_combo[:combo]["name"], discount: best_combo[:discount] }
              track_discount_stat(:combo)
              logger.info "  Applied combo discount: #{best_combo[:combo]['name']}"
            end
          end
        end

        # 4. Check for promo code usage
        if !applied && rand < DISCOUNT_PROBABILITIES[:promo_code]
          # Simulate customer having a promo code
          promo_codes = %w[SAVE10 SAVE20 FIVER TENNER HAPPYHOUR BIRTHDAY15]
          code = promo_codes.sample

          result = discount_service.apply_promo_code(
            order_id,
            code: code,
            order_total: order_total,
            line_items: line_items,
            customer: customer,
            current_time: order_time
          )

          if result
            coupon = discount_service.get_coupon_codes.find { |c| c["code"] == code }
            applied = { type: :promo_code, code: code, name: coupon&.dig("name") }
            track_discount_stat(:promo_code)
            logger.info "  Applied promo code: #{code}"
          end
        end

        # 5. Check for line-item discounts
        if !applied && rand < DISCOUNT_PROBABILITIES[:line_item]
          # Apply random line item discount to eligible items
          line_item_discounts = discount_service.load_discount_definitions.select do |d|
            d["type"]&.start_with?("line_item")
          end

          if line_item_discounts.any?
            discount = line_item_discounts.sample
            eligible_items = line_items.select do |item|
              category = item.dig("item", "categories", "elements", 0, "name") ||
                         item.dig("item", "category")
              discount["applicable_categories"]&.include?(category)
            end

            if eligible_items.any?
              item = eligible_items.first
              result = discount_service.apply_line_item_discount(
                order_id,
                line_item_id: item["id"],
                name: discount["name"],
                percentage: discount["percentage"],
                amount: discount["amount"]
              )
              if result
                applied = { type: :line_item, name: discount["name"] }
                track_discount_stat(:line_item)
                logger.info "  Applied line-item discount: #{discount['name']}"
              end
            end
          end
        end

        # 6. Check for threshold discounts
        if !applied && rand < DISCOUNT_PROBABILITIES[:threshold]
          threshold_discounts = discounts.select do |d|
            d["type"] == "threshold" && d["min_order_amount"] && order_total >= d["min_order_amount"]
          end

          if threshold_discounts.any?
            # Pick the best applicable threshold
            discount = threshold_discounts.max_by { |d| d["amount"] || 0 }
            result = services.order.apply_discount(order_id, discount_id: discount["id"])
            if result
              applied = { type: :threshold, name: discount["name"] }
              track_discount_stat(:threshold)
              logger.info "  Applied threshold discount: #{discount['name']}"
            end
          end
        end

        # 7. Fallback to legacy random discount (reduced probability)
        if !applied && rand < 0.05 && discounts.any?
          discount = discounts.sample
          result = services.order.apply_discount(order_id, discount_id: discount["id"])
          if result
            applied = { type: :legacy, name: discount["name"] }
            track_discount_stat(:legacy)
            logger.info "  Applied legacy discount: #{discount['name']}"
          end
        end

        applied
      end

      def apply_discount_by_type(order_id, discount, order_total, line_items)
        if discount["type"] == "line_item_time_based"
          # Apply to specific line items
          eligible = line_items.select do |item|
            category = item.dig("item", "categories", "elements", 0, "name") ||
                       item.dig("item", "category")
            discount["applicable_categories"]&.include?(category)
          end

          return nil if eligible.empty?

          eligible.each do |item|
            services.discount.apply_line_item_discount(
              order_id,
              line_item_id: item["id"],
              name: discount["name"],
              percentage: discount["percentage"],
              amount: discount["amount"]
            )
          end
          true
        else
          # Apply to order - try by ID first, fall back to creating inline discount
          begin
            services.order.apply_discount(order_id, discount_id: discount["id"])
          rescue CloverSandboxSimulator::ApiError => e
            # Discount ID doesn't exist in Clover, apply inline discount
            logger.debug "Discount ID not found, applying inline: #{discount['name']}"
            if discount["percentage"]
              services.order.apply_inline_discount(
                order_id,
                name: discount["name"],
                percentage: discount["percentage"]
              )
            elsif discount["amount"]
              services.order.apply_inline_discount(
                order_id,
                name: discount["name"],
                amount: discount["amount"]
              )
            else
              nil
            end
          end
        end
      end

      def track_discount_stat(type)
        @stats[:by_discount_type][type] ||= 0
        @stats[:by_discount_type][type] += 1
      end

      def select_dining_option(period)
        distribution = DINING_BY_PERIOD[period]
        random = rand(100)

        cumulative = 0
        distribution.each do |option, weight|
          cumulative += weight
          return option if random < cumulative
        end

        "HERE"
      end

      def select_items_for_period(period, data, count, party_size)
        preferred_categories = CATEGORY_PREFERENCES[period] || CATEGORY_PREFERENCES[:dinner]

        # Build weighted item pool
        weighted_items = []

        preferred_categories.each do |category|
          items = data[:items_by_category][category] || []
          # Add preferred items with higher weight
          items.each { |item| weighted_items.concat([item] * 3) }
        end

        # Add all items with lower weight for variety
        data[:items].each { |item| weighted_items << item }

        # For larger parties, ensure variety
        if party_size >= 4
          # Try to get items from different categories
          selected = []
          preferred_categories.each do |category|
            items = data[:items_by_category][category] || []
            selected << items.sample if items.any? && selected.size < count
          end

          # Fill remaining with weighted random (with safeguard against infinite loop)
          unique_items = weighted_items.uniq
          max_attempts = unique_items.size * 2
          attempts = 0
          while selected.size < count && attempts < max_attempts
            item = weighted_items.sample
            selected << item unless selected.include?(item)
            attempts += 1
          end

          selected.take(count)
        else
          weighted_items.sample(count).uniq.take(count)
        end
      end

      def calculate_tip(subtotal, dining, party_size)
        rates = TIP_RATES[dining] || TIP_RATES["HERE"]

        # Base tip percentage
        tip_percent = rand(rates[:min]..rates[:max])

        # Larger parties sometimes tip less per person but more total
        if party_size >= 6
          tip_percent = [tip_percent, 18].max # Auto-grat for large parties
        end

        # Some people don't tip on takeout
        if dining == "TO_GO" && rand < 0.3
          tip_percent = 0
        end

        (subtotal * tip_percent / 100.0).round
      end

      def process_order_payment(order_id:, subtotal:, tax_amount:, tip_amount:, employee_id:, tenders:, dining:, party_size:, gift_cards: [], gift_card_tender: nil)
        # Ensure party_size is a valid number
        party_size = party_size.to_i
        party_size = 1 if party_size < 1

        total_amount = subtotal + tax_amount

        # Check if this order should use gift card payment (~10% chance)
        use_gift_card = rand(100) < GIFT_CARD_CONFIG[:payment_chance] &&
                        gift_cards.any? &&
                        gift_card_tender

        if use_gift_card
          process_gift_card_payment(
            order_id: order_id,
            subtotal: subtotal,
            tax_amount: tax_amount,
            tip_amount: tip_amount,
            employee_id: employee_id,
            tenders: tenders,
            gift_cards: gift_cards,
            gift_card_tender: gift_card_tender
          )
          return
        end

        # Split payment more likely for larger parties dining in
        split_chance = dining == "HERE" && party_size >= 2 ? 0.25 : 0.05

        if rand < split_chance && tenders.size > 1
          num_splits = [party_size, 4, tenders.size].min
          num_splits = num_splits < 2 ? 2 : rand(2..num_splits)
          splits = select_split_tenders(tenders, num_splits)

          logger.debug "  Split payment: #{num_splits} ways"

          services.payment.process_split_payment(
            order_id: order_id,
            total_amount: subtotal,
            tip_amount: tip_amount,
            tax_amount: tax_amount,
            employee_id: employee_id,
            splits: splits
          )
        else
          # Cash more common for smaller orders
          tender = if subtotal < 2000 && rand < 0.4
                     tenders.find { |t| t["label"]&.downcase == "cash" } || tenders.sample
                   else
                     tenders.sample
                   end

          services.payment.process_payment(
            order_id: order_id,
            amount: subtotal,
            tender_id: tender["id"],
            employee_id: employee_id,
            tip_amount: tip_amount,
            tax_amount: tax_amount
          )
        end
      end

      # Process payment using a gift card (full or partial)
      def process_gift_card_payment(order_id:, subtotal:, tax_amount:, tip_amount:, employee_id:, tenders:, gift_cards:, gift_card_tender:)
        total_with_tax = subtotal + tax_amount

        # Select a gift card with some balance
        active_cards = gift_cards.select { |gc| gc["status"] == "ACTIVE" && (gc["balance"] || 0) > 0 }

        if active_cards.empty?
          logger.debug "  No active gift cards with balance, using regular payment"
          fallback_tender = tenders.reject { |t| t["id"] == gift_card_tender["id"] }.sample || tenders.sample
          services.payment.process_payment(
            order_id: order_id,
            amount: subtotal,
            tender_id: fallback_tender["id"],
            employee_id: employee_id,
            tip_amount: tip_amount,
            tax_amount: tax_amount
          )
          return
        end

        gift_card = active_cards.sample
        gc_balance = gift_card["balance"] || 0
        gc_id = gift_card["id"]

        logger.info "  🎁 Gift card payment: Card #{gc_id} has balance $#{gc_balance / 100.0}"

        # Attempt to redeem from gift card
        redeem_result = services.gift_card.redeem_gift_card(gc_id, amount: total_with_tax)

        if redeem_result[:success]
          amount_redeemed = redeem_result[:amount_redeemed]
          shortfall = redeem_result[:shortfall]

          @stats[:gift_cards][:payments] += 1
          @stats[:gift_cards][:amount_redeemed] += amount_redeemed

          if shortfall.zero?
            # Full payment covered by gift card
            logger.info "  🎁 Full payment of $#{total_with_tax / 100.0} covered by gift card"
            @stats[:gift_cards][:full_payments] += 1

            services.payment.process_payment(
              order_id: order_id,
              amount: subtotal,
              tender_id: gift_card_tender["id"],
              employee_id: employee_id,
              tip_amount: tip_amount,
              tax_amount: tax_amount
            )
          else
            # Partial payment - split between gift card and another tender
            logger.info "  🎁 Partial payment: $#{amount_redeemed / 100.0} from gift card, $#{shortfall / 100.0} remaining"
            @stats[:gift_cards][:partial_payments] += 1

            # Calculate split percentages
            gc_percentage = (amount_redeemed.to_f / total_with_tax * 100).round
            remaining_percentage = 100 - gc_percentage

            # Select another tender for the remaining amount
            other_tender = tenders.reject { |t| t["id"] == gift_card_tender["id"] }.sample || tenders.sample

            splits = [
              { tender: gift_card_tender, percentage: gc_percentage },
              { tender: other_tender, percentage: remaining_percentage }
            ]

            services.payment.process_split_payment(
              order_id: order_id,
              total_amount: subtotal,
              tip_amount: tip_amount,
              tax_amount: tax_amount,
              employee_id: employee_id,
              splits: splits
            )
          end
        else
          # Redemption failed, fall back to regular payment
          logger.warn "  Gift card redemption failed, using regular payment"
          fallback_tender = tenders.reject { |t| t["id"] == gift_card_tender["id"] }.sample || tenders.sample
          services.payment.process_payment(
            order_id: order_id,
            amount: subtotal,
            tender_id: fallback_tender["id"],
            employee_id: employee_id,
            tip_amount: tip_amount,
            tax_amount: tax_amount
          )
        end
      end

      def select_split_tenders(tenders, count)
        return [] if tenders.nil? || tenders.empty? || count.nil? || count < 1

        actual_count = [count.to_i, tenders.size].min
        selected = tenders.sample(actual_count)
        percentages = generate_split_percentages(selected.size)

        selected.zip(percentages).map do |tender, pct|
          { tender: tender, percentage: pct }
        end
      end

      def generate_split_percentages(count)
        return [100] if count == 1

        # More realistic even splits
        if rand < 0.7
          # Even split
          base = 100 / count
          remainder = 100 % count
          percentages = Array.new(count, base)
          percentages[0] += remainder
          percentages
        else
          # Random split
          points = Array.new(count - 1) { rand(20..80) }.sort

          percentages = []
          prev = 0
          points.each do |point|
            percentages << (point - prev)
            prev = point
          end
          percentages << (100 - prev)

          percentages
        end
      end

      def order_count_for_date(date)
        pattern = case date.wday
                  when 0 then ORDER_PATTERNS[:sunday]
                  when 5 then ORDER_PATTERNS[:friday]
                  when 6 then ORDER_PATTERNS[:saturday]
                  else ORDER_PATTERNS[:weekday]
                  end

        rand(pattern[:min]..pattern[:max])
      end

      def update_stats(order, period)
        @stats[:orders] += 1

        metadata = order["_metadata"] || {}
        subtotal = order["total"] || 0
        tip = metadata[:tip] || 0
        tax = metadata[:tax] || 0
        dining = metadata[:dining] || "HERE"

        @stats[:revenue] += subtotal
        @stats[:tips] += tip
        @stats[:tax] += tax

        # Track discount amount if applied
        if metadata[:discount_applied]
          @stats[:discounts] += 1
        end

        @stats[:by_period][period] ||= { orders: 0, revenue: 0 }
        @stats[:by_period][period][:orders] += 1
        @stats[:by_period][period][:revenue] += subtotal

        @stats[:by_dining][dining] ||= { orders: 0, revenue: 0 }
        @stats[:by_dining][dining][:orders] += 1
        @stats[:by_dining][dining][:revenue] += subtotal
      end

      def print_summary
        logger.info ""
        logger.info "=" * 60
        logger.info "DAILY SUMMARY"
        logger.info "=" * 60
        logger.info "  Total Orders: #{@stats[:orders]}"
        logger.info "  Revenue:      $#{'%.2f' % (@stats[:revenue] / 100.0)}"
        logger.info "  Tips:         $#{'%.2f' % (@stats[:tips] / 100.0)}"
        logger.info "  Tax:          $#{'%.2f' % (@stats[:tax] / 100.0)}"
        logger.info "  Grand Total:  $#{'%.2f' % ((@stats[:revenue] + @stats[:tips] + @stats[:tax]) / 100.0)}"
        logger.info ""
        logger.info "BY MEAL PERIOD:"
        @stats[:by_period].each do |period, data|
          avg = data[:orders] > 0 ? data[:revenue] / data[:orders] / 100.0 : 0
          logger.info "  #{period.to_s.ljust(12)} #{data[:orders].to_s.rjust(3)} orders | $#{'%.2f' % (data[:revenue] / 100.0)} | avg $#{'%.2f' % avg}"
        end
        logger.info ""
        logger.info "BY DINING OPTION:"
        @stats[:by_dining].each do |dining, data|
          logger.info "  #{dining.ljust(12)} #{data[:orders].to_s.rjust(3)} orders | $#{'%.2f' % (data[:revenue] / 100.0)}"
        end

        # Print discount stats
        if @stats[:by_discount_type].any?
          logger.info ""
          logger.info "BY DISCOUNT TYPE:"
          @stats[:by_discount_type].each do |type, count|
            logger.info "  #{type.to_s.ljust(15)} #{count} applied"
          end
          logger.info "  Total discounted orders: #{@stats[:discounts]}"
        end

        # Print gift card stats if any gift card transactions occurred
        if @stats[:gift_cards][:payments] > 0 || @stats[:gift_cards][:purchases] > 0
          logger.info ""
          logger.info "GIFT CARDS:"
          if @stats[:gift_cards][:payments] > 0
            logger.info "  Payments:      #{@stats[:gift_cards][:payments]}"
            logger.info "    Full:        #{@stats[:gift_cards][:full_payments]}"
            logger.info "    Partial:     #{@stats[:gift_cards][:partial_payments]}"
            logger.info "  Redeemed:      $#{'%.2f' % (@stats[:gift_cards][:amount_redeemed] / 100.0)}"
          end
          if @stats[:gift_cards][:purchases] > 0
            logger.info "  Purchases:     #{@stats[:gift_cards][:purchases]}"
          end
        end

        # Print refund stats if any refunds occurred
        if @stats[:refunds][:total] > 0
          logger.info ""
          logger.info "REFUNDS:"
          logger.info "  Total:         #{@stats[:refunds][:total]}"
          logger.info "    Full:        #{@stats[:refunds][:full]}"
          logger.info "    Partial:     #{@stats[:refunds][:partial]}"
          logger.info "  Amount:        $#{'%.2f' % (@stats[:refunds][:amount] / 100.0)}"
        end

        logger.info "=" * 60
      end

      def random_note
        notes = [
          "No onions",
          "Extra spicy",
          "Gluten-free",
          "Allergic to nuts",
          "Light ice",
          "No salt",
          "Well done",
          "Medium rare",
          "Extra sauce on side",
          "Dressing on side",
          "No cheese",
          "Add bacon",
          "Birthday celebration",
          "Anniversary dinner",
          "VIP customer",
          "Rush order",
          "Separate checks"
        ]
        notes.sample
      end
    end
  end
end
