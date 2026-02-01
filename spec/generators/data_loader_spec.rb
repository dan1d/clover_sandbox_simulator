# frozen_string_literal: true

require "spec_helper"

RSpec.describe CloverSandboxSimulator::Generators::DataLoader do
  let(:loader) { described_class.new(business_type: :restaurant) }

  describe "#categories" do
    it "loads categories from JSON file" do
      categories = loader.categories

      expect(categories).to be_an(Array)
      expect(categories).not_to be_empty
      expect(categories.first).to have_key("name")
    end

    it "includes expected restaurant categories" do
      categories = loader.categories
      names = categories.map { |c| c["name"] }

      expect(names).to include("Appetizers")
      expect(names).to include("Entrees")
      expect(names).to include("Desserts")
    end
  end

  describe "#items" do
    it "loads items from JSON file" do
      items = loader.items

      expect(items).to be_an(Array)
      expect(items).not_to be_empty
      expect(items.first).to have_key("name")
      expect(items.first).to have_key("price")
      expect(items.first).to have_key("category")
    end

    it "includes items with proper price format (cents)" do
      items = loader.items

      # Prices should be integers (cents)
      items.each do |item|
        expect(item["price"]).to be_a(Integer)
        expect(item["price"]).to be > 0
      end
    end
  end

  describe "#discounts" do
    it "loads discounts from JSON file" do
      discounts = loader.discounts

      expect(discounts).to be_an(Array)
      expect(discounts).not_to be_empty
    end

    it "includes both percentage and fixed amount discounts" do
      discounts = loader.discounts

      has_percentage = discounts.any? { |d| d.key?("percentage") }
      has_amount = discounts.any? { |d| d.key?("amount") }

      expect(has_percentage).to be true
      expect(has_amount).to be true
    end
  end

  describe "#tenders" do
    it "loads tenders from JSON file" do
      tenders = loader.tenders

      expect(tenders).to be_an(Array)
      expect(tenders).not_to be_empty
    end

    it "does not include credit or debit cards" do
      tenders = loader.tenders
      labels = tenders.map { |t| t["label"].downcase }

      expect(labels).not_to include("credit card")
      expect(labels).not_to include("debit card")
    end

    it "includes cash and gift card" do
      tenders = loader.tenders
      labels = tenders.map { |t| t["label"] }

      expect(labels).to include("Cash")
      expect(labels).to include("Gift Card")
    end
  end

  describe "#modifiers" do
    it "loads modifier groups from JSON file" do
      modifiers = loader.modifiers

      expect(modifiers).to be_an(Array)
      expect(modifiers).not_to be_empty
    end

    it "includes modifier groups with modifiers" do
      modifiers = loader.modifiers

      modifiers.each do |group|
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

  # ============================================
  # COUPON CODES TESTS
  # ============================================

  describe "#coupon_codes" do
    it "loads coupon codes from JSON file" do
      coupons = loader.coupon_codes

      expect(coupons).to be_an(Array)
      expect(coupons).not_to be_empty
    end

    it "includes coupons with required fields" do
      coupons = loader.coupon_codes

      coupons.each do |coupon|
        expect(coupon).to have_key("code")
        expect(coupon).to have_key("discount_type")
        expect(coupon).to have_key("discount_value")
        expect(coupon).to have_key("valid_from")
        expect(coupon).to have_key("valid_until")
        expect(coupon).to have_key("active")
      end
    end

    it "includes both percentage and fixed discount types" do
      coupons = loader.coupon_codes

      has_percentage = coupons.any? { |c| c["discount_type"] == "percentage" }
      has_fixed = coupons.any? { |c| c["discount_type"] == "fixed" }

      expect(has_percentage).to be true
      expect(has_fixed).to be true
    end
  end

  describe "#active_coupon_codes" do
    it "returns only active coupon codes" do
      active = loader.active_coupon_codes

      expect(active).to be_an(Array)
      expect(active.all? { |c| c["active"] == true }).to be true
    end

    it "excludes inactive coupon codes" do
      active = loader.active_coupon_codes
      codes = active.map { |c| c["code"] }

      expect(codes).not_to include("INACTIVE")
    end
  end

  describe "#find_coupon" do
    it "finds coupon by code" do
      coupon = loader.find_coupon("SAVE10")

      expect(coupon).not_to be_nil
      expect(coupon["code"]).to eq("SAVE10")
    end

    it "finds coupon case-insensitively" do
      coupon = loader.find_coupon("save10")

      expect(coupon).not_to be_nil
      expect(coupon["code"]).to eq("SAVE10")
    end

    it "returns nil for non-existent coupon" do
      coupon = loader.find_coupon("NONEXISTENT")

      expect(coupon).to be_nil
    end
  end

  # ============================================
  # COMBO TESTS
  # ============================================

  describe "#combos" do
    it "loads combos from JSON file" do
      combos = loader.combos

      expect(combos).to be_an(Array)
      expect(combos).not_to be_empty
    end

    it "includes combos with required fields" do
      combos = loader.combos

      combos.each do |combo|
        expect(combo).to have_key("id")
        expect(combo).to have_key("name")
        expect(combo).to have_key("discount_type")
        expect(combo).to have_key("discount_value")
        expect(combo).to have_key("required_components")
        expect(combo).to have_key("active")
      end
    end

    it "includes required_components with category or items" do
      combos = loader.combos

      combos.each do |combo|
        combo["required_components"].each do |component|
          has_category = component.key?("category")
          has_items = component.key?("items")
          expect(has_category || has_items).to be true
          expect(component).to have_key("quantity")
        end
      end
    end
  end

  describe "#active_combos" do
    it "returns only active combos" do
      active = loader.active_combos

      expect(active).to be_an(Array)
      expect(active.all? { |c| c["active"] == true }).to be true
    end
  end

  describe "#find_combo" do
    it "finds combo by ID" do
      combo = loader.find_combo("classic_meal")

      expect(combo).not_to be_nil
      expect(combo["id"]).to eq("classic_meal")
      expect(combo["name"]).to eq("Classic Meal Deal")
    end

    it "returns nil for non-existent combo" do
      combo = loader.find_combo("nonexistent_combo")

      expect(combo).to be_nil
    end
  end

  # ============================================
  # DISCOUNT TYPE FILTERS
  # ============================================

  describe "#discounts_by_type" do
    it "filters discounts by type" do
      time_based = loader.discounts_by_type("time_based")

      expect(time_based).to be_an(Array)
      expect(time_based.all? { |d| d["type"] == "time_based" }).to be true
    end

    it "returns empty array for non-existent type" do
      result = loader.discounts_by_type("nonexistent")

      expect(result).to eq([])
    end
  end

  describe "#time_based_discounts" do
    it "returns time-based discounts" do
      discounts = loader.time_based_discounts

      expect(discounts).to be_an(Array)
      expect(discounts).not_to be_empty

      discounts.each do |discount|
        expect(discount["type"]).to eq("time_based")
        expect(discount).to have_key("time_rules")
      end
    end
  end

  describe "#line_item_discounts" do
    it "returns line-item discounts" do
      discounts = loader.line_item_discounts

      expect(discounts).to be_an(Array)
      expect(discounts).not_to be_empty

      discounts.each do |discount|
        expect(discount["type"]).to start_with("line_item")
      end
    end
  end

  describe "#loyalty_discounts" do
    it "returns loyalty discounts" do
      discounts = loader.loyalty_discounts

      expect(discounts).to be_an(Array)
      expect(discounts).not_to be_empty

      discounts.each do |discount|
        expect(discount["type"]).to eq("loyalty")
        expect(discount).to have_key("min_visits")
      end
    end

    it "includes all loyalty tiers" do
      discounts = loader.loyalty_discounts
      names = discounts.map { |d| d["name"] }

      expect(names).to include("Loyalty - Bronze")
      expect(names).to include("Loyalty - Silver")
      expect(names).to include("Loyalty - Gold")
      expect(names).to include("Loyalty - Platinum")
    end
  end

  describe "#threshold_discounts" do
    it "returns threshold discounts" do
      discounts = loader.threshold_discounts

      expect(discounts).to be_an(Array)
      expect(discounts).not_to be_empty

      discounts.each do |discount|
        expect(discount["type"]).to eq("threshold")
        expect(discount).to have_key("min_order_amount")
      end
    end
  end
end
