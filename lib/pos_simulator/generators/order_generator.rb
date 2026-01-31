# frozen_string_literal: true

module PosSimulator
  module Generators
    # Generates realistic restaurant orders and payments
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

      attr_reader :services, :logger, :stats

      def initialize(services: nil)
        @services = services || Services::Clover::ServicesManager.new
        @logger = PosSimulator.logger
        @stats = { orders: 0, revenue: 0, tips: 0, tax: 0, by_period: {}, by_dining: {} }
      end

      # Generate a realistic day of restaurant operations
      def generate_realistic_day(date: Date.today, multiplier: 1.0)
        count = (order_count_for_date(date) * multiplier).to_i
        
        logger.info "=" * 60
        logger.info "🍽️  Generating realistic restaurant day: #{date}"
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
          logger.info "📍 #{period.to_s.upcase} SERVICE: #{period_count} orders"
          
          period_count.times do |i|
            order = create_realistic_order(
              period: period,
              data: data,
              order_num: i + 1,
              total_in_period: period_count
            )
            
            if order
              orders << order
              update_stats(order, period)
            end
          end
        end

        print_summary
        orders
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
          logger.info "-" * 40
          logger.info "Creating order #{i + 1}/#{count} (#{period})"
          
          order = create_realistic_order(
            period: period,
            data: data,
            order_num: i + 1,
            total_in_period: count
          )
          
          if order
            orders << order
            update_stats(order, period)
          end
        end

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
          discounts: discounts
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

      def create_realistic_order(period:, data:, order_num:, total_in_period:)
        config = MEAL_PERIODS[period]
        employee = data[:employees].sample
        
        # 60% of orders have customer info (regulars, rewards members)
        customer = data[:customers].sample if rand < 0.6

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

        services.order.add_line_items(order_id, line_items)

        # Apply discount (15% chance, higher for regulars)
        discount_chance = customer ? 0.20 : 0.10
        if rand < discount_chance && data[:discounts].any?
          discount = select_appropriate_discount(data[:discounts], period)
          services.order.apply_discount(order_id, discount_id: discount["id"]) if discount
        end

        # Calculate totals
        subtotal = services.order.calculate_total(order_id)
        services.order.update_total(order_id, subtotal)

        # Calculate tax and tip (tip varies by dining option)
        tax_amount = services.tax.calculate_tax(subtotal)
        tip_amount = calculate_tip(subtotal, dining, party_size)

        # Process payment
        process_order_payment(
          order_id: order_id,
          subtotal: subtotal,
          tax_amount: tax_amount,
          tip_amount: tip_amount,
          employee_id: employee["id"],
          tenders: data[:tenders],
          dining: dining,
          party_size: party_size
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
          tax: tax_amount
        }
        
        final_order
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
          
          # Fill remaining with weighted random
          while selected.size < count
            item = weighted_items.sample
            selected << item unless selected.include?(item)
          end
          
          selected.take(count)
        else
          weighted_items.sample(count).uniq.take(count)
        end
      end

      def select_appropriate_discount(discounts, period)
        # Happy hour discounts more likely during happy hour
        if period == :happy_hour
          happy_discount = discounts.find { |d| d["name"]&.downcase&.include?("happy") }
          return happy_discount if happy_discount && rand < 0.5
        end
        
        discounts.sample
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

      def process_order_payment(order_id:, subtotal:, tax_amount:, tip_amount:, employee_id:, tenders:, dining:, party_size:)
        # Ensure party_size is a valid number
        party_size = party_size.to_i
        party_size = 1 if party_size < 1
        
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
        logger.info "📊 DAILY SUMMARY"
        logger.info "=" * 60
        logger.info "  Total Orders: #{@stats[:orders]}"
        logger.info "  Revenue:      $#{'%.2f' % (@stats[:revenue] / 100.0)}"
        logger.info "  Tips:         $#{'%.2f' % (@stats[:tips] / 100.0)}"
        logger.info "  Tax:          $#{'%.2f' % (@stats[:tax] / 100.0)}"
        logger.info "  Grand Total:  $#{'%.2f' % ((@stats[:revenue] + @stats[:tips] + @stats[:tax]) / 100.0)}"
        logger.info ""
        logger.info "📍 BY MEAL PERIOD:"
        @stats[:by_period].each do |period, data|
          avg = data[:orders] > 0 ? data[:revenue] / data[:orders] / 100.0 : 0
          logger.info "  #{period.to_s.ljust(12)} #{data[:orders].to_s.rjust(3)} orders | $#{'%.2f' % (data[:revenue] / 100.0)} | avg $#{'%.2f' % avg}"
        end
        logger.info ""
        logger.info "🍽️  BY DINING OPTION:"
        @stats[:by_dining].each do |dining, data|
          logger.info "  #{dining.ljust(12)} #{data[:orders].to_s.rjust(3)} orders | $#{'%.2f' % (data[:revenue] / 100.0)}"
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
