# frozen_string_literal: true

require "spec_helper"

RSpec.describe CloverSandboxSimulator::Models::Category, :db do
  describe "validations" do
    it "requires name" do
      cat = build(:category, name: nil)
      expect(cat).not_to be_valid
      expect(cat.errors[:name]).to include("can't be blank")
    end

    it "enforces name uniqueness within a business_type" do
      bt = create(:business_type, :restaurant)
      create(:category, name: "Appetizers", business_type: bt)
      dup = build(:category, name: "Appetizers", business_type: bt)
      expect(dup).not_to be_valid
      expect(dup.errors[:name]).to include("has already been taken")
    end

    it "allows the same name in different business_types" do
      bt1 = create(:business_type, :restaurant)
      bt2 = create(:business_type, :pizzeria)
      create(:category, name: "Specials", business_type: bt1)
      expect(build(:category, name: "Specials", business_type: bt2)).to be_valid
    end
  end

  describe "associations" do
    it "belongs_to business_type" do
      cat = create(:category, :appetizers)
      expect(cat.business_type).to be_a(CloverSandboxSimulator::Models::BusinessType)
    end

    it "has_many items with cascade delete" do
      cat = create(:category, :appetizers)
      create(:item, :buffalo_wings, category: cat)
      expect { cat.destroy }.to change { CloverSandboxSimulator::Models::Item.count }.by(-1)
    end
  end

  describe "scopes" do
    let!(:bt) { create(:business_type, :restaurant) }

    it ".sorted orders by sort_order" do
      create(:category, name: "Desserts", sort_order: 3, business_type: bt)
      create(:category, name: "Appetizers", sort_order: 1, business_type: bt)
      create(:category, name: "Entrées", sort_order: 2, business_type: bt)
      expect(described_class.sorted.pluck(:name)).to eq(["Appetizers", "Entrées", "Desserts"])
    end

    it "does not apply a default ordering" do
      expect(described_class.all.to_sql).not_to include("ORDER BY")
    end

    it ".with_items returns only categories that have items" do
      cat_with = create(:category, name: "Apps", business_type: bt)
      create(:category, name: "Empty", business_type: bt)
      create(:item, :buffalo_wings, category: cat_with)
      expect(described_class.with_items.pluck(:name)).to eq(["Apps"])
    end
  end

  describe "tax_group" do
    it "stores food tax_group" do
      cat = create(:category, :appetizers)
      expect(cat.tax_group).to eq("food")
    end

    it "stores beverage tax_group" do
      cat = create(:category, :coffee_espresso)
      expect(cat.tax_group).to eq("beverage")
    end

    it "stores alcohol tax_group" do
      cat = create(:category, :draft_beer)
      expect(cat.tax_group).to eq("alcohol")
    end

    it "stores retail tax_group" do
      cat = create(:category, :tops)
      expect(cat.tax_group).to eq("retail")
    end

    it "stores service tax_group" do
      cat = create(:category, :haircuts)
      expect(cat.tax_group).to eq("service")
    end
  end
end
