# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Modifier Groups Integration", :vcr do
  let(:merchant_config) { get_merchant_config("QA TEST LOCAL 2") }

  before(:each) do
    skip "QA TEST LOCAL 2 merchant not found in .env.json" unless merchant_config

    # Configure the simulator with real credentials
    CloverSandboxSimulator.configure do |config|
      config.merchant_id = merchant_config["CLOVER_MERCHANT_ID"]
      config.api_token = merchant_config["CLOVER_API_TOKEN"]
      config.environment = "https://sandbox.dev.clover.com/"
      config.log_level = Logger::DEBUG
    end
  end

  describe "InventoryService" do
    let(:inventory_service) do
      CloverSandboxSimulator::Services::Clover::InventoryService.new(
        config: CloverSandboxSimulator.configuration
      )
    end

    describe "#get_modifier_groups", vcr: { cassette_name: "integration/modifier_groups/get_all" } do
      it "fetches all modifier groups from Clover" do
        result = inventory_service.get_modifier_groups

        expect(result).to be_an(Array)
        # Each modifier group should have expected structure
        result.each do |mg|
          expect(mg).to have_key("id")
          expect(mg).to have_key("name")
        end
      end
    end

    describe "#create_modifier_group", vcr: { cassette_name: "integration/modifier_groups/create_group" } do
      it "creates a new modifier group" do
        group_name = "VCR Test Group #{Time.now.to_i}"

        result = inventory_service.create_modifier_group(
          name: group_name,
          min_required: 0,
          max_allowed: 3
        )

        expect(result).to be_a(Hash)
        expect(result["id"]).not_to be_nil
        expect(result["name"]).to eq(group_name)
      end
    end

    describe "#create_modifier", vcr: { cassette_name: "integration/modifier_groups/create_modifier" } do
      it "creates a modifier within a group" do
        # First create a group
        group = inventory_service.create_modifier_group(
          name: "VCR Test Group for Modifier #{Time.now.to_i}",
          min_required: 0,
          max_allowed: 5
        )

        expect(group["id"]).not_to be_nil

        # Then create a modifier in that group
        modifier = inventory_service.create_modifier(
          modifier_group_id: group["id"],
          name: "Extra Cheese",
          price: 150
        )

        expect(modifier).to be_a(Hash)
        expect(modifier["id"]).not_to be_nil
        expect(modifier["name"]).to eq("Extra Cheese")
        expect(modifier["price"]).to eq(150)
      end
    end

    describe "#delete_modifier_group", vcr: { cassette_name: "integration/modifier_groups/delete_group" } do
      it "deletes a modifier group" do
        # First create a group to delete
        group = inventory_service.create_modifier_group(
          name: "VCR Test Group to Delete #{Time.now.to_i}",
          min_required: 0,
          max_allowed: 1
        )

        expect(group["id"]).not_to be_nil

        # Delete it
        result = inventory_service.delete_modifier_group(group["id"])

        # Clover returns empty response on successful delete
        expect(result).to be_nil.or eq({})
      end
    end
  end

  describe "EntityGenerator" do
    let(:services) do
      CloverSandboxSimulator::Services::Clover::ServicesManager.new(
        config: CloverSandboxSimulator.configuration
      )
    end

    let(:generator) do
      CloverSandboxSimulator::Generators::EntityGenerator.new(services: services)
    end

    describe "#setup_modifier_groups", vcr: { cassette_name: "integration/entity_generator/setup_modifier_groups" } do
      it "sets up modifier groups from data files" do
        result = generator.setup_modifier_groups

        expect(result).to be_an(Array)
        # Should have created/found modifier groups from modifiers.json
        expect(result).not_to be_empty
      end
    end
  end

  describe "OrderService" do
    let(:order_service) do
      CloverSandboxSimulator::Services::Clover::OrderService.new(
        config: CloverSandboxSimulator.configuration
      )
    end

    let(:inventory_service) do
      CloverSandboxSimulator::Services::Clover::InventoryService.new(
        config: CloverSandboxSimulator.configuration
      )
    end

    describe "#add_modification", vcr: { cassette_name: "integration/order_service/add_modification" } do
      it "adds a modifier to a line item on a real order" do
        # First, get an item and create an order
        items = inventory_service.get_items
        skip "No items in merchant" if items.empty?

        modifier_groups = inventory_service.get_modifier_groups
        skip "No modifier groups in merchant" if modifier_groups.empty?

        # Find a modifier to use
        modifier = modifier_groups.first.dig("modifiers", "elements", 0)
        skip "No modifiers available" unless modifier

        # Create an order with a line item
        order = order_service.create_order(employee_id: nil)
        expect(order).not_to be_nil
        expect(order["id"]).not_to be_nil

        order_id = order["id"]

        # Add a line item
        line_item = order_service.add_line_item(order_id, item_id: items.first["id"])
        expect(line_item).not_to be_nil
        expect(line_item["id"]).not_to be_nil

        # Add the modifier to the line item
        result = order_service.add_modification(
          order_id,
          line_item_id: line_item["id"],
          modifier_id: modifier["id"]
        )

        expect(result).to be_a(Hash)
        expect(result["id"]).not_to be_nil

        # Clean up - delete the order
        order_service.delete_order(order_id)
      end
    end
  end
end
