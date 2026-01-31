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
end
