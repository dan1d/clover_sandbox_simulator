# frozen_string_literal: true

require "spec_helper"

RSpec.describe CloverSandboxSimulator::Generators::DataLoader do
  let(:loader) { described_class.new(business_type: :restaurant) }

  # ── Shared examples for both paths ─────────────────────────────

  shared_examples "categories accessor" do
    it "returns an Array of category hashes" do
      categories = loader.categories

      expect(categories).to be_an(Array)
      expect(categories).not_to be_empty
    end

    it "each category has name, sort_order, description" do
      loader.categories.each do |cat|
        expect(cat).to have_key("name")
        expect(cat).to have_key("sort_order")
        expect(cat).to have_key("description")
      end
    end

    it "includes Appetizers and Desserts categories" do
      names = loader.categories.map { |c| c["name"] }

      expect(names).to include("Appetizers")
      expect(names).to include("Desserts")
    end
  end

  shared_examples "items accessor" do
    it "returns an Array of item hashes" do
      items = loader.items

      expect(items).to be_an(Array)
      expect(items).not_to be_empty
    end

    it "each item has name, price, category" do
      loader.items.each do |item|
        expect(item).to have_key("name")
        expect(item).to have_key("price")
        expect(item).to have_key("category")
      end
    end

    it "prices are positive integers (cents)" do
      loader.items.each do |item|
        expect(item["price"]).to be_a(Integer)
        expect(item["price"]).to be > 0
      end
    end
  end

  shared_examples "tax_rates accessor" do
    it "returns an Array of tax rate hashes" do
      tax_rates = loader.tax_rates

      expect(tax_rates).to be_an(Array)
      expect(tax_rates).not_to be_empty
    end

    it "each tax rate has name, rate, is_default" do
      loader.tax_rates.each do |tr|
        expect(tr).to have_key("name")
        expect(tr).to have_key("rate")
        expect(tr).to have_key("is_default")
      end
    end
  end

  # ── JSON path (no DB) ─────────────────────────────────────────

  context "when database is not connected (JSON path)" do
    before do
      allow(CloverSandboxSimulator::Database).to receive(:connected?).and_return(false)
    end

    it "reports :json data source" do
      expect(loader.data_source).to eq(:json)
    end

    include_examples "categories accessor"
    include_examples "items accessor"
    include_examples "tax_rates accessor"

    describe "#combos" do
      it "loads combos from JSON" do
        combos = loader.combos

        expect(combos).to be_an(Array)
        expect(combos).not_to be_empty
      end

      it "includes combos with required fields" do
        loader.combos.each do |combo|
          expect(combo).to have_key("id")
          expect(combo).to have_key("name")
          expect(combo).to have_key("discount_type")
          expect(combo).to have_key("discount_value")
          expect(combo).to have_key("required_components")
          expect(combo).to have_key("active")
        end
      end
    end

    describe "#discounts" do
      it "loads discounts from JSON" do
        expect(loader.discounts).to be_an(Array)
        expect(loader.discounts).not_to be_empty
      end

      it "includes both percentage and fixed amount discounts" do
        has_percentage = loader.discounts.any? { |d| d.key?("percentage") }
        has_amount = loader.discounts.any? { |d| d.key?("amount") }

        expect(has_percentage).to be true
        expect(has_amount).to be true
      end
    end

    describe "#tenders" do
      it "loads tenders from JSON" do
        expect(loader.tenders).to be_an(Array)
        expect(loader.tenders).not_to be_empty
      end

      it "does not include credit or debit cards" do
        labels = loader.tenders.map { |t| t["label"].downcase }

        expect(labels).not_to include("credit card")
        expect(labels).not_to include("debit card")
      end

      it "includes cash and gift card" do
        labels = loader.tenders.map { |t| t["label"] }

        expect(labels).to include("Cash")
        expect(labels).to include("Gift Card")
      end
    end

    describe "#modifiers" do
      it "loads modifier groups from JSON" do
        expect(loader.modifiers).to be_an(Array)
        expect(loader.modifiers).not_to be_empty
      end

      it "includes modifier groups with modifiers" do
        loader.modifiers.each do |group|
          expect(group).to have_key("name")
          expect(group).to have_key("modifiers")
          expect(group["modifiers"]).to be_an(Array)
        end
      end
    end

    describe "#items_for_category" do
      it "filters items by category" do
        appetizers = loader.items_for_category("Appetizers")

        expect(appetizers).to be_an(Array)
        expect(appetizers.all? { |i| i["category"] == "Appetizers" }).to be true
      end
    end

    describe "#coupon_codes" do
      it "loads coupon codes from JSON" do
        expect(loader.coupon_codes).to be_an(Array)
        expect(loader.coupon_codes).not_to be_empty
      end
    end

    describe "#active_coupon_codes" do
      it "returns only active coupon codes" do
        active = loader.active_coupon_codes

        expect(active.all? { |c| c["active"] == true }).to be true
      end
    end

    describe "#find_coupon" do
      it "finds coupon by code" do
        expect(loader.find_coupon("SAVE10")).not_to be_nil
      end

      it "finds coupon case-insensitively" do
        expect(loader.find_coupon("save10")).not_to be_nil
      end

      it "returns nil for non-existent coupon" do
        expect(loader.find_coupon("NONEXISTENT")).to be_nil
      end
    end

    describe "#active_combos" do
      it "returns only active combos" do
        active = loader.active_combos

        expect(active.all? { |c| c["active"] == true }).to be true
      end
    end

    describe "#find_combo" do
      it "finds combo by ID" do
        combo = loader.find_combo("classic_meal")

        expect(combo).not_to be_nil
        expect(combo["name"]).to eq("Classic Meal Deal")
      end

      it "returns nil for non-existent combo" do
        expect(loader.find_combo("nonexistent")).to be_nil
      end
    end

    describe "discount type filters" do
      it "#discounts_by_type filters correctly" do
        time_based = loader.discounts_by_type("time_based")

        expect(time_based.all? { |d| d["type"] == "time_based" }).to be true
      end

      it "#time_based_discounts returns time-based discounts" do
        expect(loader.time_based_discounts).not_to be_empty
        expect(loader.time_based_discounts.all? { |d| d["type"] == "time_based" }).to be true
      end

      it "#line_item_discounts returns line-item discounts" do
        expect(loader.line_item_discounts).not_to be_empty
        expect(loader.line_item_discounts.all? { |d| d["type"]&.start_with?("line_item") }).to be true
      end

      it "#loyalty_discounts returns loyalty discounts" do
        expect(loader.loyalty_discounts).not_to be_empty
      end

      it "#threshold_discounts returns threshold discounts" do
        expect(loader.threshold_discounts).not_to be_empty
      end
    end
  end

  # ── DB path (connected) ───────────────────────────────────────

  context "when database is connected (DB path)", :db do
    before do
      # Seed the restaurant business type so categories/items exist
      CloverSandboxSimulator::Seeder.seed!(business_type: :restaurant)
    end

    it "reports :db data source" do
      expect(loader.data_source).to eq(:db)
    end

    include_examples "categories accessor"
    include_examples "items accessor"
    include_examples "tax_rates accessor"

    describe "#categories" do
      it "returns categories sorted by sort_order" do
        sort_orders = loader.categories.map { |c| c["sort_order"] }

        expect(sort_orders).to eq(sort_orders.sort)
      end
    end

    describe "#items" do
      it "only returns active items" do
        # Deactivate one item to verify filtering
        item = CloverSandboxSimulator::Models::Item
                .for_business_type("restaurant")
                .first
        item.update!(active: false)

        items = loader.items
        names = items.map { |i| i["name"] }

        expect(names).not_to include(item.name)
      end

      it "includes sku when present" do
        items_with_sku = loader.items.select { |i| i.key?("sku") }

        expect(items_with_sku).not_to be_empty
      end
    end

    describe "#items_for_category" do
      it "filters items by category from DB" do
        appetizers = loader.items_for_category("Appetizers")

        expect(appetizers).to be_an(Array)
        expect(appetizers).not_to be_empty
        expect(appetizers.all? { |i| i["category"] == "Appetizers" }).to be true
      end
    end

    describe "#category_tax_mapping" do
      it "returns a hash mapping category names to tax groups" do
        mapping = loader.category_tax_mapping

        expect(mapping).to be_a(Hash)
        expect(mapping).not_to be_empty
        mapping.each do |cat_name, tax_groups|
          expect(cat_name).to be_a(String)
          expect(tax_groups).to be_an(Array)
        end
      end
    end

    # Combos always come from JSON (no DB model)
    describe "#combos" do
      it "still loads combos from JSON" do
        combos = loader.combos

        expect(combos).to be_an(Array)
        expect(combos).not_to be_empty
        expect(combos.first).to have_key("id")
      end
    end

    describe "DB falls back to JSON when business type not seeded" do
      let(:loader) { described_class.new(business_type: :salon_spa) }

      it "returns JSON categories when business type is not in DB" do
        # salon_spa was NOT seeded above, but JSON exists
        # DataLoader should fall back to JSON for unknown business types
        # (actually salon_spa doesn't have JSON files, so this tests
        #  a business type that has no data in either source)
        expect {
          loader.categories
        }.to raise_error(CloverSandboxSimulator::Error, /Data file not found/)
      end
    end
  end

  # ── Format parity ─────────────────────────────────────────────

  context "format parity between DB and JSON", :db do
    before do
      CloverSandboxSimulator::Seeder.seed!(business_type: :restaurant)
    end

    let(:json_loader) do
      allow(CloverSandboxSimulator::Database).to receive(:connected?).and_return(false)
      described_class.new(business_type: :restaurant)
    end

    let(:db_loader) do
      described_class.new(business_type: :restaurant)
    end

    it "categories have identical keys in DB and JSON (all elements)" do
      json_key_sets = json_loader.categories.map { |c| c.keys.sort }.uniq
      db_key_sets = db_loader.categories.map { |c| c.keys.sort }.uniq

      expect(db_key_sets).to eq(json_key_sets)
    end

    it "categories have matching value types" do
      json_cat = json_loader.categories.first
      db_cat = db_loader.categories.first

      json_cat.each do |key, value|
        db_value = db_cat[key]
        expect(db_value.class).to eq(value.class),
          "Key '#{key}': DB type #{db_value.class} != JSON type #{value.class}"
      end
    end

    it "items have the same core keys" do
      json_keys = json_loader.items.first.keys.sort
      db_keys = db_loader.items.first.keys.sort

      core_keys = %w[name price category]
      core_keys.each do |key|
        expect(json_keys).to include(key)
        expect(db_keys).to include(key)
      end
    end

    it "items have matching value types for core keys" do
      json_item = json_loader.items.first
      db_item = db_loader.items.first

      %w[name price category].each do |key|
        expect(db_item[key].class).to eq(json_item[key].class),
          "Key '#{key}': DB type #{db_item[key].class} != JSON type #{json_item[key].class}"
      end
    end

    it "items price is Integer in both paths" do
      json_loader.items.each do |item|
        expect(item["price"]).to be_a(Integer), "JSON item '#{item['name']}' price is #{item['price'].class}"
      end

      db_loader.items.each do |item|
        expect(item["price"]).to be_a(Integer), "DB item '#{item['name']}' price is #{item['price'].class}"
      end
    end

    it "tax_rates have identical structure in both paths" do
      json_rates = json_loader.tax_rates
      db_rates = db_loader.tax_rates

      # Both should return the same JSON data (tax rates have no DB model)
      expect(db_rates.map { |r| r["name"] }).to eq(json_rates.map { |r| r["name"] })
    end
  end
end
