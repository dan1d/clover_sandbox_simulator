# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Multi-business type integration", :db, :integration do
  let(:bt_model) { CloverSandboxSimulator::Models::BusinessType }
  let(:cat_model) { CloverSandboxSimulator::Models::Category }
  let(:item_model) { CloverSandboxSimulator::Models::Item }
  let(:seeder) { CloverSandboxSimulator::Seeder }

  before do
    # Seed all 9 business types — idempotent so safe to call per-example
    CloverSandboxSimulator::Seeder.seed!
  end

  # ── Order profile validation per business type ─────────────────

  describe "order_profile configuration" do
    seeder_types = CloverSandboxSimulator::Seeder::SEED_MAP.keys

    seeder_types.each do |bt_trait|
      context "#{bt_trait}" do
        let(:bt) { bt_model.find_by!(key: bt_trait.to_s) }
        let(:profile) { bt.order_profile }

        it "has a valid order_profile hash" do
          expect(profile).to be_a(Hash)
          expect(profile).not_to be_empty
        end

        it "has avg_order_value_cents as a positive integer" do
          expect(profile["avg_order_value_cents"]).to be_a(Integer)
          expect(profile["avg_order_value_cents"]).to be > 0
        end

        it "has avg_items_per_order >= 1" do
          expect(profile["avg_items_per_order"]).to be >= 1
        end

        it "has peak_hours as non-empty array of time strings" do
          hours = profile["peak_hours"]
          expect(hours).to be_an(Array)
          expect(hours).not_to be_empty
          hours.each do |h|
            expect(h).to match(/\A\d{2}:\d{2}\z/),
              "peak_hour '#{h}' is not in HH:MM format"
          end
        end

        it "has meal_periods as an array" do
          expect(profile["meal_periods"]).to be_an(Array)
        end

        it "has dining_options as an array" do
          expect(profile["dining_options"]).to be_an(Array)
        end

        it "has tip_percentage_range as [min, max]" do
          range = profile["tip_percentage_range"]
          expect(range).to be_an(Array)
          expect(range.size).to eq(2)
          expect(range[0]).to be <= range[1]
        end

        it "has a non-negative tax_rate" do
          expect(profile["tax_rate"]).to be >= 0
        end
      end
    end
  end

  # ── Industry grouping ──────────────────────────────────────────

  describe "industry classification" do
    it "food industry types have meal_periods" do
      food_types = bt_model.where(industry: "food")
      expect(food_types).not_to be_empty

      food_types.each do |bt|
        periods = bt.order_profile["meal_periods"]
        expect(periods).not_to be_empty,
          "Food type '#{bt.key}' should have meal_periods but has #{periods.inspect}"
      end
    end

    it "retail industry types have no meal_periods" do
      retail_types = bt_model.where(industry: "retail")
      expect(retail_types).not_to be_empty

      retail_types.each do |bt|
        periods = bt.order_profile["meal_periods"]
        expect(periods).to be_empty,
          "Retail type '#{bt.key}' should not have meal_periods but has #{periods.inspect}"
      end
    end

    it "retail types have zero tip range" do
      retail_types = bt_model.where(industry: "retail")

      retail_types.each do |bt|
        tip_range = bt.order_profile["tip_percentage_range"]
        expect(tip_range).to eq([0, 0]),
          "Retail type '#{bt.key}' should have [0,0] tip range but has #{tip_range.inspect}"
      end
    end

    it "service industry types have positive tip range" do
      service_types = bt_model.where(industry: "service")
      expect(service_types).not_to be_empty

      service_types.each do |bt|
        tip_range = bt.order_profile["tip_percentage_range"]
        expect(tip_range[1]).to be > 0,
          "Service type '#{bt.key}' should have positive tip max"
      end
    end
  end

  # ── Time block configuration (peak hours) ──────────────────────

  describe "time block configuration" do
    it "all peak hours are within business hours (06:00-23:59)" do
      bt_model.all.each do |bt|
        profile = bt.order_profile
        next unless profile

        profile["peak_hours"]&.each do |hour_str|
          hour = hour_str.split(":").first.to_i
          expect(hour).to be_between(6, 23),
            "#{bt.key} peak_hour '#{hour_str}' is outside business hours"
        end
      end
    end

    it "food types have at least 2 peak hours" do
      food_types = bt_model.where(industry: "food")

      food_types.each do |bt|
        hours = bt.order_profile["peak_hours"]
        expect(hours.size).to be >= 2,
          "Food type '#{bt.key}' should have >= 2 peak hours"
      end
    end

    it "fine_dining peak hours are in evening (17:00+)" do
      fine_dining = bt_model.find_by!(key: "fine_dining")
      fine_dining.order_profile["peak_hours"].each do |hour_str|
        hour = hour_str.split(":").first.to_i
        expect(hour).to be >= 17,
          "Fine dining peak hour '#{hour_str}' should be evening"
      end
    end

    it "cafe_bakery has morning peak hours" do
      cafe = bt_model.find_by!(key: "cafe_bakery")
      hours = cafe.order_profile["peak_hours"].map { |h| h.split(":").first.to_i }
      expect(hours.any? { |h| h < 12 }).to be(true),
        "Cafe/bakery should have at least one morning peak hour"
    end
  end

  # ── Tip/payment distributions ──────────────────────────────────

  describe "tip and payment distributions" do
    it "food service types (HERE) have minimum 15% tip" do
      food_here = bt_model.where(industry: "food").select do |bt|
        bt.order_profile&.dig("dining_options")&.include?("HERE")
      end

      food_here.each do |bt|
        tip_min = bt.order_profile["tip_percentage_range"][0]
        expect(tip_min).to be >= 10,
          "#{bt.key} dine-in tip min should be >= 10% but is #{tip_min}%"
      end
    end

    it "fine_dining has the highest tip range" do
      fine_dining = bt_model.find_by!(key: "fine_dining")
      fd_max = fine_dining.order_profile["tip_percentage_range"][1]

      other_food = bt_model.where(industry: "food").where.not(key: "fine_dining")

      other_food.each do |bt|
        other_max = bt.order_profile["tip_percentage_range"][1]
        expect(fd_max).to be >= other_max,
          "Fine dining tip max (#{fd_max}) should be >= #{bt.key} tip max (#{other_max})"
      end
    end

    it "fine_dining has the highest avg_order_value" do
      fine_dining = bt_model.find_by!(key: "fine_dining")
      fd_value = fine_dining.order_profile["avg_order_value_cents"]

      bt_model.where.not(key: "fine_dining").each do |bt|
        other_value = bt.order_profile&.dig("avg_order_value_cents") || 0
        expect(fd_value).to be >= other_value,
          "Fine dining avg ($#{fd_value / 100.0}) should be >= #{bt.key} avg ($#{other_value / 100.0})"
      end
    end

    it "food_truck and cafe_bakery have lower avg_order_value than restaurant" do
      restaurant = bt_model.find_by!(key: "restaurant")
      rest_value = restaurant.order_profile["avg_order_value_cents"]

      %w[food_truck cafe_bakery].each do |key|
        bt = bt_model.find_by!(key: key)
        value = bt.order_profile["avg_order_value_cents"]
        expect(value).to be < rest_value,
          "#{key} avg ($#{value / 100.0}) should be < restaurant avg ($#{rest_value / 100.0})"
      end
    end

    it "dining options are realistic for each business type" do
      # Food truck is TO_GO only
      food_truck = bt_model.find_by!(key: "food_truck")
      expect(food_truck.order_profile["dining_options"]).to eq(["TO_GO"])

      # Bar/nightclub is dine-in only
      bar = bt_model.find_by!(key: "bar_nightclub")
      expect(bar.order_profile["dining_options"]).to eq(["HERE"])

      # Restaurant supports all options
      restaurant = bt_model.find_by!(key: "restaurant")
      expect(restaurant.order_profile["dining_options"]).to include("HERE", "TO_GO", "DELIVERY")
    end
  end

  # ── Category/item integrity per business type ──────────────────

  describe "category and item integrity" do
    CloverSandboxSimulator::Seeder::SEED_MAP.each do |bt_trait, categories_map|
      context "#{bt_trait}" do
        let(:bt) { bt_model.find_by!(key: bt_trait.to_s) }

        it "has the expected number of categories" do
          expected = categories_map.size
          expect(bt.categories.count).to eq(expected)
        end

        it "has the expected total number of items" do
          expected = categories_map.values.sum(&:size)
          expect(item_model.for_business_type(bt_trait.to_s).count).to eq(expected)
        end

        it "every category has at least 3 items" do
          bt.categories.each do |cat|
            expect(cat.items.count).to be >= 3,
              "#{bt_trait} category '#{cat.name}' has only #{cat.items.count} items"
          end
        end

        it "all items have positive prices" do
          item_model.for_business_type(bt_trait.to_s).find_each do |item|
            expect(item.price).to be > 0,
              "#{bt_trait} item '#{item.name}' has price #{item.price}"
          end
        end
      end
    end
  end
end
