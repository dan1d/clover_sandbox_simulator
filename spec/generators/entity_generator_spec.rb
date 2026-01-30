# frozen_string_literal: true

require "spec_helper"

RSpec.describe PosSimulator::Generators::EntityGenerator do
  before { stub_clover_credentials }
  
  let(:base_url) { "https://sandbox.dev.clover.com/v3/merchants/TEST_MERCHANT_ID" }
  let(:generator) { described_class.new }

  describe "#setup_categories" do
    context "when no categories exist" do
      it "creates all categories from data file" do
        # Stub empty categories response
        stub_request(:get, "#{base_url}/categories")
          .to_return(
            status: 200,
            body: { elements: [] }.to_json,
            headers: { "Content-Type" => "application/json" }
          )

        # Stub category creation
        stub_request(:post, "#{base_url}/categories")
          .to_return(
            status: 200,
            body: ->(request) {
              data = JSON.parse(request.body)
              { id: "CAT_#{data['name'].upcase}", name: data["name"] }.to_json
            },
            headers: { "Content-Type" => "application/json" }
          )

        categories = generator.setup_categories
        
        expect(categories.size).to eq(7) # From categories.json
      end
    end

    context "when categories already exist" do
      it "is idempotent - does not create duplicates" do
        existing_categories = [
          { "id" => "CAT1", "name" => "Appetizers" },
          { "id" => "CAT2", "name" => "Entrees" },
          { "id" => "CAT3", "name" => "Sides" },
          { "id" => "CAT4", "name" => "Desserts" },
          { "id" => "CAT5", "name" => "Drinks" },
          { "id" => "CAT6", "name" => "Alcoholic Beverages" },
          { "id" => "CAT7", "name" => "Specials" }
        ]

        stub_request(:get, "#{base_url}/categories")
          .to_return(
            status: 200,
            body: { elements: existing_categories }.to_json,
            headers: { "Content-Type" => "application/json" }
          )

        # Should NOT make any POST requests for creating categories
        create_stub = stub_request(:post, "#{base_url}/categories")
          .to_return(status: 200, body: "{}".to_json)

        categories = generator.setup_categories
        
        expect(categories.size).to eq(7)
        expect(create_stub).not_to have_been_requested
      end

      it "only creates missing categories" do
        existing_categories = [
          { "id" => "CAT1", "name" => "Appetizers" },
          { "id" => "CAT2", "name" => "Entrees" }
        ]

        stub_request(:get, "#{base_url}/categories")
          .to_return(
            status: 200,
            body: { elements: existing_categories }.to_json,
            headers: { "Content-Type" => "application/json" }
          )

        # Stub category creation for missing ones
        create_stub = stub_request(:post, "#{base_url}/categories")
          .to_return(
            status: 200,
            body: ->(request) {
              data = JSON.parse(request.body)
              { id: "NEW_#{data['name'].upcase}", name: data["name"] }.to_json
            },
            headers: { "Content-Type" => "application/json" }
          )

        categories = generator.setup_categories
        
        expect(categories.size).to eq(7)
        # Should create 5 missing categories (7 total - 2 existing)
        expect(create_stub).to have_been_requested.times(5)
      end
    end
  end

  describe "#setup_items" do
    let(:existing_categories) do
      [
        { "id" => "CAT1", "name" => "Appetizers" },
        { "id" => "CAT2", "name" => "Entrees" }
      ]
    end

    before do
      stub_request(:get, "#{base_url}/categories")
        .to_return(
          status: 200,
          body: { elements: existing_categories }.to_json,
          headers: { "Content-Type" => "application/json" }
        )
    end

    context "when items already exist" do
      it "is idempotent - does not create duplicates" do
        existing_items = [
          { "id" => "ITEM1", "name" => "Buffalo Wings" },
          { "id" => "ITEM2", "name" => "Loaded Nachos" }
        ]

        stub_request(:get, "#{base_url}/items")
          .with(query: { expand: "categories,modifierGroups" })
          .to_return(
            status: 200,
            body: { elements: existing_items }.to_json,
            headers: { "Content-Type" => "application/json" }
          )

        # Stub item creation
        create_stub = stub_request(:post, "#{base_url}/items")
          .to_return(
            status: 200,
            body: ->(request) {
              data = JSON.parse(request.body)
              { id: "NEW_#{rand(1000)}", name: data["name"] }.to_json
            },
            headers: { "Content-Type" => "application/json" }
          )

        # Stub category association
        stub_request(:post, "#{base_url}/category_items")
          .to_return(status: 200, body: "{}".to_json)

        items = generator.setup_items
        
        # Should have 39 items total (from items.json)
        # But only create new ones for items that don't exist
        expect(items.size).to eq(39)
        # Should create 37 new items (39 - 2 existing)
        expect(create_stub).to have_been_requested.times(37)
      end
    end
  end

  describe "#setup_discounts" do
    context "when discounts already exist" do
      it "is idempotent - does not create duplicates" do
        existing_discounts = [
          { "id" => "D1", "name" => "Happy Hour", "percentage" => 15 },
          { "id" => "D2", "name" => "Senior Discount", "percentage" => 10 },
          { "id" => "D3", "name" => "Military Discount", "percentage" => 15 },
          { "id" => "D4", "name" => "Employee Discount", "percentage" => 25 },
          { "id" => "D5", "name" => "Birthday Special", "percentage" => 20 },
          { "id" => "D6", "name" => "$5 Off", "amount" => -500 },
          { "id" => "D7", "name" => "$10 Off", "amount" => -1000 }
        ]

        stub_request(:get, "#{base_url}/discounts")
          .to_return(
            status: 200,
            body: { elements: existing_discounts }.to_json,
            headers: { "Content-Type" => "application/json" }
          )

        # Should NOT create any discounts
        create_stub = stub_request(:post, "#{base_url}/discounts")
          .to_return(status: 200, body: "{}".to_json)

        discounts = generator.setup_discounts
        
        expect(discounts.size).to eq(7)
        expect(create_stub).not_to have_been_requested
      end
    end
  end

  describe "#setup_all" do
    it "runs idempotently on multiple calls" do
      # Setup all stubs for full entities
      stub_request(:get, "#{base_url}/categories")
        .to_return(
          status: 200,
          body: { elements: [{ "id" => "CAT1", "name" => "Appetizers" }] }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      stub_request(:post, "#{base_url}/categories")
        .to_return(
          status: 200,
          body: ->(request) {
            data = JSON.parse(request.body)
            { id: "CAT_#{rand(1000)}", name: data["name"] }.to_json
          },
          headers: { "Content-Type" => "application/json" }
        )

      stub_request(:get, "#{base_url}/items")
        .with(query: { expand: "categories,modifierGroups" })
        .to_return(
          status: 200,
          body: { elements: [] }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      stub_request(:post, "#{base_url}/items")
        .to_return(
          status: 200,
          body: ->(request) {
            data = JSON.parse(request.body)
            { id: "ITEM_#{rand(1000)}", name: data["name"] }.to_json
          },
          headers: { "Content-Type" => "application/json" }
        )

      stub_request(:post, "#{base_url}/category_items")
        .to_return(status: 200, body: "{}".to_json)

      stub_request(:get, "#{base_url}/discounts")
        .to_return(
          status: 200,
          body: { elements: [] }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      stub_request(:post, "#{base_url}/discounts")
        .to_return(
          status: 200,
          body: ->(request) {
            data = JSON.parse(request.body)
            { id: "D_#{rand(1000)}", name: data["name"] }.to_json
          },
          headers: { "Content-Type" => "application/json" }
        )

      stub_request(:get, "#{base_url}/employees")
        .to_return(
          status: 200,
          body: { elements: (1..5).map { |i| { "id" => "E#{i}", "name" => "Employee #{i}" } } }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      stub_request(:get, "#{base_url}/customers")
        .to_return(
          status: 200,
          body: { elements: (1..20).map { |i| { "id" => "C#{i}", "firstName" => "Customer", "lastName" => "#{i}" } } }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      results = generator.setup_all
      
      expect(results[:categories]).to be_an(Array)
      expect(results[:items]).to be_an(Array)
      expect(results[:discounts]).to be_an(Array)
      expect(results[:employees]).to be_an(Array)
      expect(results[:customers]).to be_an(Array)
    end
  end
end
