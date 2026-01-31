# frozen_string_literal: true

require "spec_helper"

RSpec.describe CloverSandboxSimulator::Services::Clover::InventoryService do
  before { stub_clover_credentials }

  let(:service) { described_class.new }
  let(:base_url) { "https://sandbox.dev.clover.com/v3/merchants/TEST_MERCHANT_ID" }

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
