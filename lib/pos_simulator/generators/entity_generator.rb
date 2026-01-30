# frozen_string_literal: true

module PosSimulator
  module Generators
    # Creates restaurant entities in Clover (categories, items, discounts, etc.)
    class EntityGenerator
      attr_reader :services, :data, :logger

      def initialize(services: nil, business_type: :restaurant)
        @services = services || Services::Clover::ServicesManager.new
        @data = DataLoader.new(business_type: business_type)
        @logger = PosSimulator.logger
      end

      # Set up all entities (categories, items, discounts, etc.)
      def setup_all
        logger.info "=" * 60
        logger.info "Setting up restaurant entities in Clover..."
        logger.info "=" * 60

        results = {
          categories: setup_categories,
          items: setup_items,
          discounts: setup_discounts,
          employees: setup_employees,
          customers: setup_customers
        }

        logger.info "=" * 60
        logger.info "Entity setup complete!"
        logger.info "  Categories: #{results[:categories].size}"
        logger.info "  Items: #{results[:items].size}"
        logger.info "  Discounts: #{results[:discounts].size}"
        logger.info "  Employees: #{results[:employees].size}"
        logger.info "  Customers: #{results[:customers].size}"
        logger.info "=" * 60

        results
      end

      # Create categories from data file
      def setup_categories
        logger.info "Setting up categories..."
        
        existing = services.inventory.get_categories
        existing_names = existing.map { |c| c["name"] }

        created = []
        data.categories.each do |cat_data|
          if existing_names.include?(cat_data["name"])
            logger.debug "Category '#{cat_data["name"]}' already exists, skipping"
            created << existing.find { |c| c["name"] == cat_data["name"] }
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

      # Create items from data file
      def setup_items
        logger.info "Setting up menu items..."

        # Build category lookup
        categories = services.inventory.get_categories
        category_lookup = categories.each_with_object({}) do |cat, hash|
          hash[cat["name"]] = cat["id"]
        end

        existing = services.inventory.get_items
        existing_names = existing.map { |i| i["name"] }

        created = []
        data.items.each do |item_data|
          if existing_names.include?(item_data["name"])
            logger.debug "Item '#{item_data["name"]}' already exists, skipping"
            created << existing.find { |i| i["name"] == item_data["name"] }
          else
            category_id = category_lookup[item_data["category"]]
            
            item = services.inventory.create_item(
              name: item_data["name"],
              price: item_data["price"],
              category_id: category_id
            )
            created << item if item
          end
        end

        logger.info "Items ready: #{created.size}"
        created
      end

      # Create discounts from data file
      def setup_discounts
        logger.info "Setting up discounts..."

        existing = services.discount.get_discounts
        existing_names = existing.map { |d| d["name"] }

        created = []
        data.discounts.each do |disc_data|
          if existing_names.include?(disc_data["name"])
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

      # Ensure employees exist
      def setup_employees
        logger.info "Setting up employees..."
        employees = services.employee.ensure_employees(count: 5)
        logger.info "Employees ready: #{employees.size}"
        employees
      end

      # Ensure customers exist
      def setup_customers
        logger.info "Setting up customers..."
        customers = services.customer.ensure_customers(count: 20)
        logger.info "Customers ready: #{customers.size}"
        customers
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
