# frozen_string_literal: true

require "spec_helper"

RSpec.describe CloverSandboxSimulator::Models::BusinessType, :db do
  describe "validations" do
    it "requires key" do
      bt = build(:business_type, key: nil)
      expect(bt).not_to be_valid
      expect(bt.errors[:key]).to include("can't be blank")
    end

    it "requires name" do
      bt = build(:business_type, name: nil)
      expect(bt).not_to be_valid
      expect(bt.errors[:name]).to include("can't be blank")
    end

    it "enforces key uniqueness" do
      create(:business_type, key: "restaurant", name: "Restaurant")
      dup = build(:business_type, key: "restaurant", name: "Another")
      expect(dup).not_to be_valid
      expect(dup.errors[:key]).to include("has already been taken")
    end
  end

  describe "associations" do
    it "has_many categories with cascade delete" do
      bt = create(:business_type, :restaurant)
      create(:category, :appetizers, business_type: bt)
      expect { bt.destroy }.to change { described_class.reflect_on_association(:categories).klass.count }.by(-1)
    end

    it "has_many items through categories" do
      bt = create(:business_type, :restaurant)
      cat = create(:category, :appetizers, business_type: bt)
      create(:item, :buffalo_wings, category: cat)
      expect(bt.items.count).to eq(1)
    end

    it "nullifies simulated_orders on destroy" do
      bt = create(:business_type, :restaurant)
      order = create(:simulated_order, :paid, business_type: bt)
      bt.destroy
      expect(order.reload.business_type_id).to be_nil
    end
  end

  describe "scopes" do
    before do
      create(:business_type, :restaurant)
      create(:business_type, :retail_clothing)
      create(:business_type, :salon_spa)
    end

    it ".food_types returns food industry" do
      expect(described_class.food_types.pluck(:key)).to eq(["restaurant"])
    end

    it ".retail_types returns retail industry" do
      expect(described_class.retail_types.pluck(:key)).to eq(["retail_clothing"])
    end

    it ".service_types returns service industry" do
      expect(described_class.service_types.pluck(:key)).to eq(["salon_spa"])
    end
  end

  describe ".find_by_key!" do
    it "returns the business type with the given key" do
      create(:business_type, :restaurant)
      expect(described_class.find_by_key!("restaurant").name).to eq("Restaurant")
    end

    it "raises RecordNotFound for missing key" do
      expect { described_class.find_by_key!("nonexistent") }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "order_profile" do
    it "stores and retrieves jsonb data with string keys" do
      bt = create(:business_type, :restaurant)
      bt.reload
      expect(bt.order_profile).to be_a(Hash)
      expect(bt.order_profile["avg_order_value_cents"]).to eq(2500)
      expect(bt.order_profile["meal_periods"]).to include("lunch", "dinner")
    end
  end
end
