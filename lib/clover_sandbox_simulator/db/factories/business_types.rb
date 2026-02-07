# frozen_string_literal: true

FactoryBot.define do
  factory :business_type, class: "CloverSandboxSimulator::Models::BusinessType" do
    sequence(:key) { |n| "business_type_#{n}" }
    name { "Test Business Type" }
    industry { "food" }
    order_profile { {} }

    # ── Food (6) ──────────────────────────────────────────────

    trait :restaurant do
      key { "restaurant" }
      name { "Restaurant" }
      industry { "food" }
      description { "Full-service casual dining restaurant" }
      order_profile do
        {
          avg_order_value_cents: 2500,
          avg_items_per_order: 3,
          peak_hours: %w[11:30 12:30 18:00 19:30],
          meal_periods: %w[breakfast lunch dinner],
          dining_options: %w[HERE TO_GO DELIVERY],
          tip_percentage_range: [15, 25],
          tax_rate: 8.875
        }
      end
    end

    trait :cafe_bakery do
      key { "cafe_bakery" }
      name { "Café & Bakery" }
      industry { "food" }
      description { "Coffee shop with fresh-baked pastries and light fare" }
      order_profile do
        {
          avg_order_value_cents: 1200,
          avg_items_per_order: 2,
          peak_hours: %w[07:00 08:30 12:00],
          meal_periods: %w[breakfast lunch],
          dining_options: %w[HERE TO_GO],
          tip_percentage_range: [10, 20],
          tax_rate: 8.875
        }
      end
    end

    trait :bar_nightclub do
      key { "bar_nightclub" }
      name { "Bar & Nightclub" }
      industry { "food" }
      description { "Full bar with craft cocktails, draft beer, and late-night bites" }
      order_profile do
        {
          avg_order_value_cents: 3500,
          avg_items_per_order: 4,
          peak_hours: %w[17:00 21:00 23:00],
          meal_periods: %w[dinner late_night],
          dining_options: %w[HERE],
          tip_percentage_range: [18, 25],
          tax_rate: 8.875
        }
      end
    end

    trait :food_truck do
      key { "food_truck" }
      name { "Food Truck" }
      industry { "food" }
      description { "Mobile street food — tacos, burritos, and Mexican fare" }
      order_profile do
        {
          avg_order_value_cents: 1400,
          avg_items_per_order: 3,
          peak_hours: %w[11:30 12:30 18:00],
          meal_periods: %w[lunch dinner],
          dining_options: %w[TO_GO],
          tip_percentage_range: [10, 20],
          tax_rate: 8.875
        }
      end
    end

    trait :fine_dining do
      key { "fine_dining" }
      name { "Fine Dining" }
      industry { "food" }
      description { "Upscale prix-fixe and à la carte dining experience" }
      order_profile do
        {
          avg_order_value_cents: 12000,
          avg_items_per_order: 4,
          peak_hours: %w[18:00 19:30 20:30],
          meal_periods: %w[dinner],
          dining_options: %w[HERE],
          tip_percentage_range: [20, 30],
          tax_rate: 8.875
        }
      end
    end

    trait :pizzeria do
      key { "pizzeria" }
      name { "Pizzeria" }
      industry { "food" }
      description { "Pizza shop with classic and specialty pies, calzones, and sides" }
      order_profile do
        {
          avg_order_value_cents: 2200,
          avg_items_per_order: 3,
          peak_hours: %w[12:00 18:00 20:00],
          meal_periods: %w[lunch dinner],
          dining_options: %w[HERE TO_GO DELIVERY],
          tip_percentage_range: [12, 20],
          tax_rate: 8.875
        }
      end
    end

    # ── Retail (2) ────────────────────────────────────────────

    trait :retail_clothing do
      key { "retail_clothing" }
      name { "Clothing Store" }
      industry { "retail" }
      description { "Casual wear and accessories with size/color variants" }
      order_profile do
        {
          avg_order_value_cents: 7500,
          avg_items_per_order: 2,
          peak_hours: %w[11:00 14:00 17:00],
          meal_periods: [],
          dining_options: [],
          tip_percentage_range: [0, 0],
          tax_rate: 8.875
        }
      end
    end

    trait :retail_general do
      key { "retail_general" }
      name { "General Store" }
      industry { "retail" }
      description { "Everyday essentials — electronics, home goods, personal care" }
      order_profile do
        {
          avg_order_value_cents: 3500,
          avg_items_per_order: 3,
          peak_hours: %w[10:00 13:00 17:00],
          meal_periods: [],
          dining_options: [],
          tip_percentage_range: [0, 0],
          tax_rate: 8.875
        }
      end
    end

    # ── Services (1) ──────────────────────────────────────────

    trait :salon_spa do
      key { "salon_spa" }
      name { "Salon & Spa" }
      industry { "service" }
      description { "Full-service hair salon, spa treatments, and nail services" }
      order_profile do
        {
          avg_order_value_cents: 8500,
          avg_items_per_order: 2,
          peak_hours: %w[10:00 13:00 16:00],
          meal_periods: [],
          dining_options: [],
          tip_percentage_range: [15, 25],
          tax_rate: 0.0
        }
      end
    end
  end
end
