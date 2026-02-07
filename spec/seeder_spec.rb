# frozen_string_literal: true

require "spec_helper"

RSpec.describe CloverSandboxSimulator::Seeder, :db do
  include FactoryBot::Syntax::Methods

  let(:bt_model) { CloverSandboxSimulator::Models::BusinessType }
  let(:cat_model) { CloverSandboxSimulator::Models::Category }
  let(:item_model) { CloverSandboxSimulator::Models::Item }

  # ── Idempotency ─────────────────────────────────────────────

  describe "idempotency" do
    it "creates no duplicates when seed! is called twice" do
      described_class.seed!
      first_counts = {
        business_types: bt_model.count,
        categories: cat_model.count,
        items: item_model.count
      }

      described_class.seed!
      second_counts = {
        business_types: bt_model.count,
        categories: cat_model.count,
        items: item_model.count
      }

      expect(second_counts).to eq(first_counts)
    end

    it "returns consistent summary counts on repeated calls" do
      result1 = described_class.seed!
      result2 = described_class.seed!

      expect(result1).to eq(result2)
    end
  end

  # ── Completeness ────────────────────────────────────────────

  describe "completeness" do
    before { described_class.seed! }

    it "creates all 9 business types" do
      expect(bt_model.count).to eq(9)
    end

    it "creates all 38 categories" do
      expect(cat_model.count).to eq(38)
    end

    it "creates all 168 items" do
      expect(item_model.count).to eq(168)
    end

    it "includes all expected business type keys" do
      expected_keys = %w[
        restaurant cafe_bakery bar_nightclub food_truck fine_dining
        pizzeria retail_clothing retail_general salon_spa
      ]
      expect(bt_model.pluck(:key).sort).to eq(expected_keys.sort)
    end
  end

  # ── Category counts per business type ───────────────────────

  describe "category counts" do
    before { described_class.seed! }

    {
      "restaurant" => 5,
      "cafe_bakery" => 5,
      "bar_nightclub" => 5,
      "food_truck" => 3,
      "fine_dining" => 3,
      "pizzeria" => 3,
      "retail_clothing" => 5,
      "retail_general" => 5,
      "salon_spa" => 4
    }.each do |bt_key, expected_count|
      it "#{bt_key} has #{expected_count} categories" do
        bt = bt_model.find_by!(key: bt_key)
        expect(bt.categories.count).to eq(expected_count)
      end
    end
  end

  # ── Item counts per category ────────────────────────────────

  describe "item counts" do
    before { described_class.seed! }

    it "every category has >= 3 items" do
      cat_model.find_each do |cat|
        expect(cat.items.count).to be >= 3,
          "Category '#{cat.name}' (#{cat.business_type.key}) has only #{cat.items.count} items"
      end
    end

    it "restaurant categories each have 5 items" do
      bt = bt_model.find_by!(key: "restaurant")
      bt.categories.find_each do |cat|
        expect(cat.items.count).to eq(5),
          "Restaurant category '#{cat.name}' has #{cat.items.count} items, expected 5"
      end
    end
  end

  # ── Data integrity ──────────────────────────────────────────

  describe "data integrity" do
    before { described_class.seed! }

    it "all prices are positive integers (cents)" do
      item_model.find_each do |item|
        expect(item.price).to be_a(Integer),
          "Item '#{item.name}' price is #{item.price.class}, expected Integer"
        expect(item.price).to be > 0,
          "Item '#{item.name}' price is #{item.price}, expected > 0"
      end
    end

    it "all items have SKU values" do
      item_model.find_each do |item|
        expect(item.sku).to be_present,
          "Item '#{item.name}' is missing a SKU"
      end
    end

    it "clothing items have variants with sizes and/or colors" do
      bt = bt_model.find_by!(key: "retail_clothing")
      bt.items.find_each do |item|
        expect(item.variants).to be_an(Array),
          "Clothing item '#{item.name}' variants is #{item.variants.class}"
        expect(item.variants).not_to be_empty,
          "Clothing item '#{item.name}' has empty variants"

        variant = item.variants.first
        has_sizes = variant.key?("sizes")
        has_colors = variant.key?("colors")
        expect(has_sizes || has_colors).to be(true),
          "Clothing item '#{item.name}' variant has neither 'sizes' nor 'colors'"
      end
    end

    it "non-clothing items have empty variants" do
      non_clothing = item_model.joins(category: :business_type)
                                .where.not(business_types: { key: "retail_clothing" })
      non_clothing.find_each do |item|
        expect(item.variants).to eq([]),
          "Non-clothing item '#{item.name}' has unexpected variants: #{item.variants}"
      end
    end

    it "salon services have unit set to 'session' or 'hour'" do
      bt = bt_model.find_by!(key: "salon_spa")
      bt.items.find_each do |item|
        expect(item.unit).to be_in(%w[session hour]),
          "Salon item '#{item.name}' has unit '#{item.unit}', expected 'session' or 'hour'"
      end
    end

    it "salon services have metadata with duration_minutes" do
      bt = bt_model.find_by!(key: "salon_spa")
      bt.items.find_each do |item|
        expect(item.metadata).to be_a(Hash),
          "Salon item '#{item.name}' metadata is #{item.metadata.class}"
        expect(item.metadata).to include("duration_minutes"),
          "Salon item '#{item.name}' metadata missing 'duration_minutes'"
        expect(item.metadata["duration_minutes"]).to be > 0,
          "Salon item '#{item.name}' duration is #{item.metadata['duration_minutes']}"
      end
    end

    it "non-salon items do not have a unit" do
      non_salon = item_model.joins(category: :business_type)
                             .where.not(business_types: { key: "salon_spa" })
      non_salon.find_each do |item|
        expect(item.unit).to be_nil,
          "Non-salon item '#{item.name}' has unexpected unit '#{item.unit}'"
      end
    end

    it "all items are active by default" do
      expect(item_model.where(active: false).count).to eq(0)
    end

    it "all categories have a tax_group" do
      cat_model.find_each do |cat|
        expect(cat.tax_group).to be_present,
          "Category '#{cat.name}' is missing tax_group"
      end
    end

    it "all business types have an order_profile" do
      bt_model.find_each do |bt|
        expect(bt.order_profile).to be_a(Hash),
          "BusinessType '#{bt.key}' order_profile is #{bt.order_profile.class}"
        expect(bt.order_profile).not_to be_empty,
          "BusinessType '#{bt.key}' has empty order_profile"
      end
    end
  end

  # ── Selective seeding ───────────────────────────────────────

  describe "selective seeding" do
    it "seeds only the specified business type" do
      described_class.seed!(business_type: :retail_clothing)

      expect(bt_model.count).to eq(1)
      expect(bt_model.first.key).to eq("retail_clothing")
      expect(cat_model.count).to eq(5)
      expect(item_model.count).to eq(21)
    end

    it "accepts string business type" do
      described_class.seed!(business_type: "restaurant")

      expect(bt_model.count).to eq(1)
      expect(bt_model.first.key).to eq("restaurant")
    end

    it "does not affect other business types when seeding selectively" do
      described_class.seed!(business_type: :restaurant)
      described_class.seed!(business_type: :salon_spa)

      expect(bt_model.count).to eq(2)
      expect(bt_model.pluck(:key).sort).to eq(%w[restaurant salon_spa])
    end

    it "raises ArgumentError for unknown business type" do
      expect {
        described_class.seed!(business_type: :nonexistent)
      }.to raise_error(ArgumentError, /Unknown business type: nonexistent/)
    end
  end

  # ── Industry grouping ──────────────────────────────────────

  describe "industry grouping" do
    before { described_class.seed! }

    it "food industry includes 6 business types" do
      food = bt_model.food_types
      expect(food.count).to eq(6)
      expect(food.pluck(:key).sort).to eq(
        %w[bar_nightclub cafe_bakery fine_dining food_truck pizzeria restaurant]
      )
    end

    it "retail industry includes 2 business types" do
      retail = bt_model.retail_types
      expect(retail.count).to eq(2)
      expect(retail.pluck(:key).sort).to eq(%w[retail_clothing retail_general])
    end

    it "service industry includes 1 business type" do
      service = bt_model.service_types
      expect(service.count).to eq(1)
      expect(service.first.key).to eq("salon_spa")
    end

    it "all business types belong to a valid industry" do
      bt_model.find_each do |bt|
        expect(bt.industry).to be_in(%w[food retail service]),
          "BusinessType '#{bt.key}' has invalid industry '#{bt.industry}'"
      end
    end
  end

  # ── SEED_MAP constants ─────────────────────────────────────

  describe "SEED_MAP" do
    it "covers all 9 business types" do
      expect(described_class::SEED_MAP.keys.size).to eq(9)
    end

    it "CATEGORY_COUNTS matches SEED_MAP" do
      described_class::SEED_MAP.each do |bt, cats|
        expect(described_class::CATEGORY_COUNTS[bt]).to eq(cats.size),
          "CATEGORY_COUNTS[:#{bt}] is #{described_class::CATEGORY_COUNTS[bt]}, expected #{cats.size}"
      end
    end

    it "ITEM_COUNTS matches SEED_MAP" do
      described_class::SEED_MAP.each do |_, cats|
        cats.each do |cat_trait, items|
          expect(described_class::ITEM_COUNTS[cat_trait]).to eq(items.size),
            "ITEM_COUNTS[:#{cat_trait}] is #{described_class::ITEM_COUNTS[cat_trait]}, expected #{items.size}"
        end
      end
    end
  end

  # ── Return value ────────────────────────────────────────────

  describe "return value" do
    it "returns a summary hash with counts" do
      result = described_class.seed!

      expect(result).to be_a(Hash)
      expect(result[:business_types]).to eq(9)
      expect(result[:categories]).to eq(38)
      expect(result[:items]).to eq(168)
    end

    it "returns correct counts for selective seeding" do
      result = described_class.seed!(business_type: :salon_spa)

      expect(result[:business_types]).to eq(1)
      expect(result[:categories]).to eq(4)
      expect(result[:items]).to eq(16)
    end
  end
end
