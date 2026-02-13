# frozen_string_literal: true

module CloverSandboxSimulator
  module Generators
    # Creates restaurant entities in Clover (categories, items, discounts, etc.)
    class EntityGenerator
      # Configuration constants
      DEFAULT_EMPLOYEE_COUNT = 5
      DEFAULT_CUSTOMER_COUNT = 20
      LOG_SEPARATOR = "=" * 60

      attr_reader :services, :data, :logger

      def initialize(services: nil, business_type: :restaurant)
        @services = services || Services::Clover::ServicesManager.new
        @data = DataLoader.new(business_type: business_type)
        @logger = CloverSandboxSimulator.logger
      end

      # Set up all entities (categories, items, discounts, etc.)
      def setup_all
        logger.info LOG_SEPARATOR
        logger.info "Setting up restaurant entities in Clover..."
        logger.info LOG_SEPARATOR

        results = {
          categories: setup_categories,
          items: setup_items,
          modifier_groups: setup_modifier_groups,
          discounts: setup_discounts,
          employees: setup_employees,
          customers: setup_customers,
          order_types: setup_order_types,
          tax_rates: setup_tax_rates
        }

        # Assign tax rates to items based on category
        assign_item_tax_rates(results[:items], results[:tax_rates]) if results[:items].any? && results[:tax_rates].any?

        logger.info LOG_SEPARATOR
        logger.info "Entity setup complete!"
        logger.info "  Categories: #{results[:categories].size}"
        logger.info "  Items: #{results[:items].size}"
        logger.info "  Modifier Groups: #{results[:modifier_groups].size}"
        logger.info "  Discounts: #{results[:discounts].size}"
        logger.info "  Employees: #{results[:employees].size}"
        logger.info "  Customers: #{results[:customers].size}"
        logger.info "  Order Types: #{results[:order_types].size}"
        logger.info "  Tax Rates: #{results[:tax_rates].size}"
        logger.info LOG_SEPARATOR

        results
      end

      # Create categories from data file.
      # Supports duplicate category names (common in real Clover merchants).
      # Uses (name, sortOrder) pair for idempotent matching so each duplicate
      # category instance is created separately on Clover.
      def setup_categories
        logger.info "Setting up categories..."

        existing = services.inventory.get_categories

        # Build a set of (name_lower, sortOrder) for idempotent matching.
        # This allows multiple categories with the same name but different
        # sort orders — exactly how duplicates appear in real Clover data.
        existing_keys = existing.map { |c| [c["name"]&.downcase, c["sortOrder"]].join("|") }.to_set

        created = []
        data.categories.each do |cat_data|
          key = [cat_data["name"]&.downcase, cat_data["sort_order"]].join("|")

          if existing_keys.include?(key)
            logger.debug "Category '#{cat_data["name"]}' (sort: #{cat_data["sort_order"]}) already exists, skipping"
            match = existing.find { |c| c["name"] == cat_data["name"] && c["sortOrder"] == cat_data["sort_order"] }
            created << match if match
          else
            cat = services.inventory.create_category(
              name: cat_data["name"],
              sort_order: cat_data["sort_order"]
            )
            created << cat if cat
          end
        end

        logger.info "Categories ready: #{created.size}"
        created
      end

      # Create items from data file.
      # Supports duplicate item names (common in real Clover merchants).
      # Uses SKU for idempotent matching when available, falling back to name.
      # Uses category_sort_order (when present) to assign items to the correct
      # category instance, even when multiple categories share the same name.
      def setup_items
        logger.info "Setting up menu items..."

        # Fetch current categories from Clover
        categories = services.inventory.get_categories

        # Build category lookup by sort_order → Clover ID (supports duplicates)
        category_by_sort_order = categories.each_with_object({}) do |cat, hash|
          hash[cat["sortOrder"]] = cat["id"] if cat["sortOrder"]
        end

        # Fallback: category lookup by name (last match wins — fine for non-dup data)
        category_by_name = categories.each_with_object({}) do |cat, hash|
          hash[cat["name"]] = cat["id"]
        end

        # Fetch existing items from Clover for idempotent matching
        existing = services.inventory.get_items
        existing_skus = existing.each_with_object({}) do |item, hash|
          hash[item["sku"]&.downcase] = item if item["sku"].present?
        end
        existing_names = existing.map { |i| i["name"]&.downcase }.to_set

        created = []
        data.items.each do |item_data|
          sku = item_data["sku"]

          # Check idempotency: prefer SKU match, fall back to name-only for legacy data
          if sku.present? && existing_skus.key?(sku.downcase)
            logger.debug "Item '#{item_data["name"]}' (SKU: #{sku}) already exists, skipping"
            created << existing_skus[sku.downcase]
            next
          elsif sku.blank? && existing_names.include?(item_data["name"]&.downcase)
            logger.debug "Item '#{item_data["name"]}' already exists, skipping"
            created << existing.find { |i| i["name"]&.downcase == item_data["name"]&.downcase }
            next
          end

          # Resolve category: prefer sort_order (handles duplicates), fall back to name
          category_id = if item_data["category_sort_order"]
                          category_by_sort_order[item_data["category_sort_order"]]
                        end
          category_id ||= category_by_name[item_data["category"]]

          item = services.inventory.create_item(
            name: item_data["name"],
            price: item_data["price"],
            category_id: category_id,
            sku: sku
          )
          created << item if item
        end

        logger.info "Items ready: #{created.size}"
        created
      end

      # Create discounts from data file
      def setup_discounts
        logger.info "Setting up discounts..."

        existing = services.discount.get_discounts
        existing_names = existing.map { |d| d["name"]&.downcase }

        created = []
        data.discounts.each do |disc_data|
          if existing_names.include?(disc_data["name"]&.downcase)
            logger.debug "Discount '#{disc_data["name"]}' already exists, skipping"
            created << existing.find { |d| d["name"] == disc_data["name"] }
          else
            disc = if disc_data["percentage"]
                     services.discount.create_percentage_discount(
                       name: disc_data["name"],
                       percentage: disc_data["percentage"]
                     )
                   else
                     services.discount.create_fixed_discount(
                       name: disc_data["name"],
                       amount: disc_data["amount"]
                     )
                   end
            created << disc if disc
          end
        end

        logger.info "Discounts ready: #{created.size}"
        created
      end

      # Create modifier groups from data file
      # Ensures both groups AND their child modifiers exist (idempotent)
      def setup_modifier_groups
        logger.info "Setting up modifier groups..."

        existing = services.inventory.get_modifier_groups
        existing_by_name = existing.each_with_object({}) { |mg, h| h[mg["name"]&.downcase] = mg }

        created = []
        data.modifiers.each do |group_data|
          group_name_lower = group_data["name"]&.downcase

          if existing_by_name.key?(group_name_lower)
            # Group exists - but ensure modifiers are also present
            group = existing_by_name[group_name_lower]
            logger.debug "Modifier group '#{group_data["name"]}' already exists, checking modifiers..."
            ensure_modifiers_for_group(group, group_data["modifiers"] || [])
            created << group
          else
            # Create new group and its modifiers
            group = services.inventory.create_modifier_group(
              name: group_data["name"],
              min_required: group_data["min_required"] || 0,
              max_allowed: group_data["max_allowed"]
            )

            if group && group["id"]
              # Create modifiers within the group
              (group_data["modifiers"] || []).each do |mod_data|
                services.inventory.create_modifier(
                  modifier_group_id: group["id"],
                  name: mod_data["name"],
                  price: mod_data["price"] || 0
                )
              end
            end

            created << group if group
          end
        end

        logger.info "Modifier groups ready: #{created.size}"
        created
      end

      # Ensure all modifiers exist within a group (idempotent)
      def ensure_modifiers_for_group(group, expected_modifiers)
        return if expected_modifiers.empty?

        # Get existing modifiers for this group
        existing_modifiers = group.dig("modifiers", "elements") || []
        existing_names = existing_modifiers.map { |m| m["name"]&.downcase }

        missing_count = 0
        expected_modifiers.each do |mod_data|
          next if existing_names.include?(mod_data["name"]&.downcase)

          logger.debug "  Creating missing modifier: #{mod_data["name"]}"
          services.inventory.create_modifier(
            modifier_group_id: group["id"],
            name: mod_data["name"],
            price: mod_data["price"] || 0
          )
          missing_count += 1
        end

        logger.info "  Created #{missing_count} missing modifiers for '#{group["name"]}'" if missing_count > 0
      end

      # Ensure employees exist
      def setup_employees
        logger.info "Setting up employees..."
        employees = services.employee.ensure_employees(count: DEFAULT_EMPLOYEE_COUNT)
        logger.info "Employees ready: #{employees.size}"
        employees
      end

      # Ensure customers exist
      def setup_customers
        logger.info "Setting up customers..."
        customers = services.customer.ensure_customers(count: DEFAULT_CUSTOMER_COUNT)
        logger.info "Customers ready: #{customers.size}"
        customers
      end

      # Set up order types (Dine In, Takeout, Delivery, etc.)
      def setup_order_types
        logger.info "Setting up order types..."
        order_types = services.order_type.setup_default_order_types
        logger.info "Order types ready: #{order_types.size}"
        order_types
      end

      # Set up tax rates from data file
      def setup_tax_rates
        logger.info "Setting up tax rates..."
        existing = services.tax.get_tax_rates
        existing_names = existing.map { |r| r["name"]&.downcase }

        created = []
        data.tax_rates.each do |rate_data|
          if existing_names.include?(rate_data["name"].downcase)
            logger.debug "Tax rate '#{rate_data["name"]}' already exists, skipping"
            created << existing.find { |r| r["name"]&.downcase == rate_data["name"].downcase }
          else
            rate = services.tax.create_tax_rate(
              name: rate_data["name"],
              rate: rate_data["rate"],
              is_default: rate_data["is_default"] || false
            )
            created << rate if rate
          end
        end

        logger.info "Tax rates ready: #{created.size}"
        created
      end

      # Assign tax rates to items based on category mapping
      # Assign tax rates to items based on category mapping (idempotent)
      def assign_item_tax_rates(items, tax_rates)
        logger.info "Assigning tax rates to items by category..."
        category_mapping = data.category_tax_mapping

        return if category_mapping.empty? || tax_rates.empty?

        # Build lookup for tax rates by name
        tax_rate_lookup = tax_rates.each_with_object({}) do |rate, hash|
          hash[rate["name"]&.downcase] = rate["id"]
        end

        # Build lookup of existing item-tax associations
        existing_associations = build_item_tax_association_lookup(items, tax_rates)

        assigned_count = 0
        skipped_count = 0
        items.each do |item|
          category = item.dig("categories", "elements", 0, "name") || item["category"]
          next unless category

          applicable_taxes = category_mapping[category] || category_mapping["default"] || []

          applicable_taxes.each do |tax_name|
            tax_rate_id = tax_rate_lookup[tax_name.downcase]
            next unless tax_rate_id

            # Check if association already exists
            item_associations = existing_associations[item["id"]] || []
            if item_associations.include?(tax_rate_id)
              skipped_count += 1
              next
            end

            begin
              services.tax.associate_item_with_tax_rate(item["id"], tax_rate_id)
              assigned_count += 1
            rescue StandardError => e
              logger.debug "Could not assign tax to item #{item["id"]}: #{e.message}"
            end
          end
        end

        logger.info "Assigned #{assigned_count} new tax rate associations (#{skipped_count} already existed)"
      end

      # Build lookup of existing item-tax associations
      # @return [Hash] { item_id => [tax_rate_ids] }
      def build_item_tax_association_lookup(items, tax_rates)
        associations = {}

        # Try to fetch existing associations from each tax rate
        tax_rates.each do |rate|
          begin
            items_for_rate = services.tax.get_items_for_tax_rate(rate["id"])
            items_for_rate.each do |item|
              associations[item["id"]] ||= []
              associations[item["id"]] << rate["id"]
            end
          rescue StandardError => e
            logger.debug "Could not fetch items for tax rate #{rate["id"]}: #{e.message}"
          end
        end

        associations
      end

      # Delete all entities (for clean slate)
      def delete_all
        logger.warn "=" * 60
        logger.warn "DELETING ALL ENTITIES..."
        logger.warn "=" * 60

        services.inventory.delete_all

        services.discount.get_discounts.each do |d|
          services.discount.delete_discount(d["id"])
        end

        logger.info "All entities deleted"
      end
    end
  end
end
