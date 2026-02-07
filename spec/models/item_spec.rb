# frozen_string_literal: true

require "spec_helper"

RSpec.describe CloverSandboxSimulator::Models::Item, :db do
  describe "validations" do
    it "requires name" do
      item = build(:item, name: nil)
      expect(item).not_to be_valid
      expect(item.errors[:name]).to include("can't be blank")
    end

    it "requires price" do
      item = build(:item, price: nil)
      expect(item).not_to be_valid
      expect(item.errors[:price]).to include("can't be blank")
    end

    it "requires price to be a non-negative integer" do
      expect(build(:item, price: -1)).not_to be_valid
      expect(build(:item, price: 0)).to be_valid
      expect(build(:item, price: 999)).to be_valid
    end

    it "rejects non-integer price" do
      expect(build(:item, price: 9.99)).not_to be_valid
    end

    it "enforces name uniqueness within a category" do
      cat = create(:category, :appetizers)
      create(:item, name: "Wings", price: 1299, category: cat)
      dup = build(:item, name: "Wings", price: 999, category: cat)
      expect(dup).not_to be_valid
    end

    it "allows the same name in different categories" do
      bt = create(:business_type, :restaurant)
      cat1 = create(:category, name: "Appetizers", business_type: bt)
      cat2 = create(:category, name: "Desserts", business_type: bt)
      create(:item, name: "Special", price: 999, category: cat1)
      expect(build(:item, name: "Special", price: 999, category: cat2)).to be_valid
    end
  end

  describe "associations" do
    it "belongs_to category" do
      item = create(:item, :buffalo_wings)
      expect(item.category).to be_a(CloverSandboxSimulator::Models::Category)
    end
  end

  describe "scopes" do
    let!(:cat) { create(:category, :appetizers) }

    before do
      create(:item, name: "Wings", price: 1299, active: true, category: cat)
      create(:item, name: "Old Item", price: 500, active: false, category: cat)
    end

    it ".active returns only active items" do
      expect(described_class.active.pluck(:name)).to eq(["Wings"])
    end

    it ".inactive returns only inactive items" do
      expect(described_class.inactive.pluck(:name)).to eq(["Old Item"])
    end

    it ".for_business_type filters by business type key" do
      bt_key = cat.business_type.key
      expect(described_class.for_business_type(bt_key).count).to eq(2)
      expect(described_class.for_business_type("nonexistent").count).to eq(0)
    end

    it ".in_category filters by category name" do
      expect(described_class.in_category("Appetizers").count).to eq(2)
      expect(described_class.in_category("Nonexistent").count).to eq(0)
    end
  end

  describe "variants jsonb" do
    it "stores size/color variants for clothing items" do
      item = create(:item, :classic_tshirt)
      item.reload
      expect(item.variants).to be_an(Array)
      expect(item.variants.first).to include("sizes" => %w[S M L XL])
      expect(item.variants.first).to include("colors" => %w[Black White Navy])
    end

    it "defaults to empty array for non-clothing items" do
      item = create(:item, :buffalo_wings)
      expect(item.variants).to eq([])
    end
  end

  describe "unit field" do
    it "stores session unit for salon services" do
      item = create(:item, :womens_haircut)
      expect(item.unit).to eq("session")
    end

    it "stores hour unit for spa treatments" do
      item = create(:item, :swedish_massage)
      expect(item.unit).to eq("hour")
    end

    it "is nil for food/retail items" do
      item = create(:item, :buffalo_wings)
      expect(item.unit).to be_nil
    end
  end

  describe "#price_dollars" do
    it "converts cents to dollars" do
      item = build(:item, :buffalo_wings)
      expect(item.price_dollars).to eq(12.99)
    end

    it "handles nil price" do
      item = build(:item, price: nil)
      expect(item.price_dollars).to eq(0.0)
    end
  end
end
