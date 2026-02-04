# frozen_string_literal: true

module CloverSandboxSimulator
  module Services
    module Clover
      # Manages Clover inventory: categories, items, modifiers
      class InventoryService < BaseService
        # Fetch all categories
        def get_categories
          logger.info "Fetching categories..."
          response = request(:get, endpoint("categories"))
          elements = response&.dig("elements") || []
          logger.info "Found #{elements.size} categories"
          elements
        end

        # Create a category
        def create_category(name:, sort_order: nil)
          logger.info "Creating category: #{name}"
          payload = { "name" => name }
          payload["sortOrder"] = sort_order if sort_order
          request(:post, endpoint("categories"), payload: payload)
        end

        # Delete a category
        def delete_category(category_id)
          logger.info "Deleting category: #{category_id}"
          request(:delete, endpoint("categories/#{category_id}"))
        end

        # Fetch all items
        def get_items
          logger.info "Fetching items..."
          response = request(:get, endpoint("items"), params: { expand: "categories,modifierGroups" })
          elements = response&.dig("elements") || []
          # Filter out deleted items
          active_items = elements.reject { |item| item["deleted"] == true }
          logger.info "Found #{active_items.size} active items"
          active_items
        end

        # Create an item
        def create_item(name:, price:, category_id: nil, sku: nil, hidden: false)
          logger.info "Creating item: #{name} ($#{price / 100.0})"

          payload = {
            "name" => name,
            "price" => price,
            "priceType" => "FIXED",
            "hidden" => hidden,
            "defaultTaxRates" => true
          }
          payload["sku"] = sku if sku

          item = request(:post, endpoint("items"), payload: payload)

          # Associate with category if provided
          if item && category_id
            associate_item_with_category(item["id"], category_id)
          end

          item
        end

        # Associate item with category
        def associate_item_with_category(item_id, category_id)
          logger.debug "Associating item #{item_id} with category #{category_id}"
          request(:post, endpoint("category_items"), payload: {
            "elements" => [{ "item" => { "id" => item_id }, "category" => { "id" => category_id } }]
          })
        end

        # Delete an item
        def delete_item(item_id)
          logger.info "Deleting item: #{item_id}"
          request(:delete, endpoint("items/#{item_id}"))
        end

        # Fetch all modifier groups
        def get_modifier_groups
          logger.info "Fetching modifier groups..."
          response = request(:get, endpoint("modifier_groups"), params: { expand: "modifiers" })
          elements = response&.dig("elements") || []
          logger.info "Found #{elements.size} modifier groups"
          elements
        end

        # Create a modifier group
        def create_modifier_group(name:, min_required: 0, max_allowed: nil)
          logger.info "Creating modifier group: #{name}"
          payload = {
            "name" => name,
            "minRequired" => min_required
          }
          payload["maxAllowed"] = max_allowed if max_allowed
          request(:post, endpoint("modifier_groups"), payload: payload)
        end

      # Create a modifier within a group
      def create_modifier(modifier_group_id:, name:, price: 0)
        logger.info "Creating modifier: #{name} in group #{modifier_group_id}"
        request(:post, endpoint("modifier_groups/#{modifier_group_id}/modifiers"), payload: {
          "name" => name,
          "price" => price
        })
      end

      # Associate a modifier group with an item
      def associate_item_with_modifier_group(item_id, modifier_group_id)
        logger.debug "Associating item #{item_id} with modifier group #{modifier_group_id}"
        request(:post, endpoint("item_modifier_groups"), payload: {
          "elements" => [{ "item" => { "id" => item_id }, "modifierGroup" => { "id" => modifier_group_id } }]
        })
      end

      # Delete a modifier group
      def delete_modifier_group(modifier_group_id)
        logger.info "Deleting modifier group: #{modifier_group_id}"
        request(:delete, endpoint("modifier_groups/#{modifier_group_id}"))
      end

      # Delete all categories and items
        def delete_all
          logger.warn "Deleting all inventory..."

          get_items.each { |item| delete_item(item["id"]) }
          get_categories.each { |cat| delete_category(cat["id"]) }

          logger.info "All inventory deleted"
        end
      end
    end
  end
end
