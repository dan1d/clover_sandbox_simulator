# frozen_string_literal: true

require "spec_helper"

RSpec.describe CloverSandboxSimulator::Services::Clover::InventoryService do
  before { stub_clover_credentials }

  let(:service) { described_class.new }
  let(:base_url) { "https://sandbox.dev.clover.com/v3/merchants/TEST_MERCHANT_ID" }

  # ============================================
  # Modifier Groups
  # ============================================

  describe "#get_modifier_groups" do
    it "fetches modifier groups from Clover API" do
      stub_request(:get, "#{base_url}/modifier_groups")
        .with(query: { expand: "modifiers" })
        .to_return(
          status: 200,
          body: {
            elements: [
              { id: "MG1", name: "Temperature", modifiers: { elements: [{ id: "M1", name: "Rare" }] } }
            ]
          }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      groups = service.get_modifier_groups

      expect(groups).to be_an(Array)
      expect(groups.first["name"]).to eq("Temperature")
    end

    it "returns empty array when no modifier groups exist" do
      stub_request(:get, "#{base_url}/modifier_groups")
        .with(query: { expand: "modifiers" })
        .to_return(
          status: 200,
          body: { elements: [] }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      groups = service.get_modifier_groups

      expect(groups).to eq([])
    end
  end

  describe "#create_modifier_group" do
    it "creates a new modifier group" do
      stub_request(:post, "#{base_url}/modifier_groups")
        .with(body: { name: "Temperature", minRequired: 0, maxAllowed: 1 }.to_json)
        .to_return(
          status: 200,
          body: { id: "MG1", name: "Temperature", minRequired: 0, maxAllowed: 1 }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      group = service.create_modifier_group(name: "Temperature", min_required: 0, max_allowed: 1)

      expect(group["id"]).to eq("MG1")
      expect(group["name"]).to eq("Temperature")
    end

    it "creates a modifier group without max_allowed" do
      stub_request(:post, "#{base_url}/modifier_groups")
        .with(body: { name: "Add-Ons", minRequired: 0 }.to_json)
        .to_return(
          status: 200,
          body: { id: "MG2", name: "Add-Ons", minRequired: 0 }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      group = service.create_modifier_group(name: "Add-Ons", min_required: 0)

      expect(group["id"]).to eq("MG2")
    end
  end

  describe "#create_modifier" do
    it "creates a modifier within a group" do
      stub_request(:post, "#{base_url}/modifier_groups/MG1/modifiers")
        .with(body: { name: "Medium Rare", price: 0 }.to_json)
        .to_return(
          status: 200,
          body: { id: "MOD1", name: "Medium Rare", price: 0 }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      modifier = service.create_modifier(modifier_group_id: "MG1", name: "Medium Rare", price: 0)

      expect(modifier["id"]).to eq("MOD1")
      expect(modifier["name"]).to eq("Medium Rare")
    end

    it "creates a modifier with a price" do
      stub_request(:post, "#{base_url}/modifier_groups/MG2/modifiers")
        .with(body: { name: "Extra Cheese", price: 150 }.to_json)
        .to_return(
          status: 200,
          body: { id: "MOD2", name: "Extra Cheese", price: 150 }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      modifier = service.create_modifier(modifier_group_id: "MG2", name: "Extra Cheese", price: 150)

      expect(modifier["id"]).to eq("MOD2")
      expect(modifier["price"]).to eq(150)
    end
  end

  describe "#associate_item_with_modifier_group" do
    it "associates a modifier group with an item" do
      stub_request(:post, "#{base_url}/item_modifier_groups")
        .with(body: {
          elements: [{ item: { id: "ITEM1" }, modifierGroup: { id: "MG1" } }]
        }.to_json)
        .to_return(status: 200, body: "{}".to_json)

      result = service.associate_item_with_modifier_group("ITEM1", "MG1")

      expect(result).not_to be_nil
    end
  end

  describe "#delete_modifier_group" do
    it "deletes a modifier group" do
      stub_request(:delete, "#{base_url}/modifier_groups/MG1")
        .to_return(status: 200, body: "".to_json)

      expect { service.delete_modifier_group("MG1") }.not_to raise_error
    end
  end

  describe "#get_categories" do
    it "fetches categories from Clover API" do
      stub_request(:get, "#{base_url}/categories")
        .to_return(
          status: 200,
          body: { elements: [{ id: "CAT1", name: "Appetizers" }] }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      categories = service.get_categories

      expect(categories).to be_an(Array)
      expect(categories.first["name"]).to eq("Appetizers")
    end

    it "returns empty array when no categories exist" do
      stub_request(:get, "#{base_url}/categories")
        .to_return(
          status: 200,
          body: { elements: [] }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      categories = service.get_categories

      expect(categories).to eq([])
    end
  end

  describe "#create_category" do
    it "creates a new category" do
      stub_request(:post, "#{base_url}/categories")
        .with(body: { name: "Desserts", sortOrder: 4 }.to_json)
        .to_return(
          status: 200,
          body: { id: "CAT2", name: "Desserts", sortOrder: 4 }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      category = service.create_category(name: "Desserts", sort_order: 4)

      expect(category["id"]).to eq("CAT2")
      expect(category["name"]).to eq("Desserts")
    end
  end

  describe "#get_items" do
    it "fetches items and filters out deleted ones" do
      stub_request(:get, "#{base_url}/items")
        .with(query: { expand: "categories,modifierGroups" })
        .to_return(
          status: 200,
          body: {
            elements: [
              { id: "ITEM1", name: "Burger", deleted: false },
              { id: "ITEM2", name: "Old Item", deleted: true },
              { id: "ITEM3", name: "Fries" }
            ]
          }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      items = service.get_items

      expect(items.size).to eq(2)
      expect(items.map { |i| i["name"] }).to contain_exactly("Burger", "Fries")
    end
  end

  describe "#create_item" do
    it "creates an item and associates with category" do
      # Stub item creation
      stub_request(:post, "#{base_url}/items")
        .with(body: hash_including("name" => "Wings", "price" => 1299))
        .to_return(
          status: 200,
          body: { id: "ITEM1", name: "Wings", price: 1299 }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      # Stub category association
      stub_request(:post, "#{base_url}/category_items")
        .to_return(status: 200, body: "{}".to_json)

      item = service.create_item(name: "Wings", price: 1299, category_id: "CAT1")

      expect(item["id"]).to eq("ITEM1")
      expect(item["name"]).to eq("Wings")
    end
  end
end
