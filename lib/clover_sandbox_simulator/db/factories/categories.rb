# frozen_string_literal: true

FactoryBot.define do
  factory :category, class: "CloverSandboxSimulator::Models::Category" do
    association :business_type
    sequence(:name) { |n| "Category #{n}" }
    sort_order { 0 }

    # ── Restaurant ────────────────────────────────────────────

    trait :appetizers do
      name { "Appetizers" }
      sort_order { 1 }
      description { "Starters and shareables" }
      tax_group { "food" }
      association :business_type, factory: [:business_type, :restaurant]
    end

    trait :entrees do
      name { "Entrées" }
      sort_order { 2 }
      description { "Main courses" }
      tax_group { "food" }
      association :business_type, factory: [:business_type, :restaurant]
    end

    trait :sides do
      name { "Sides" }
      sort_order { 3 }
      description { "Side dishes" }
      tax_group { "food" }
      association :business_type, factory: [:business_type, :restaurant]
    end

    trait :desserts do
      name { "Desserts" }
      sort_order { 4 }
      description { "Sweet finishes" }
      tax_group { "food" }
      association :business_type, factory: [:business_type, :restaurant]
    end

    trait :beverages do
      name { "Beverages" }
      sort_order { 5 }
      description { "Non-alcoholic drinks" }
      tax_group { "beverage" }
      association :business_type, factory: [:business_type, :restaurant]
    end

    # ── Café & Bakery ─────────────────────────────────────────

    trait :coffee_espresso do
      name { "Coffee & Espresso" }
      sort_order { 1 }
      description { "Hot and cold coffee drinks" }
      tax_group { "beverage" }
      association :business_type, factory: [:business_type, :cafe_bakery]
    end

    trait :pastries do
      name { "Pastries & Baked Goods" }
      sort_order { 2 }
      description { "Freshly baked daily" }
      tax_group { "food" }
      association :business_type, factory: [:business_type, :cafe_bakery]
    end

    trait :breakfast do
      name { "Breakfast" }
      sort_order { 3 }
      description { "Morning plates and bowls" }
      tax_group { "food" }
      association :business_type, factory: [:business_type, :cafe_bakery]
    end

    trait :sandwiches do
      name { "Sandwiches & Wraps" }
      sort_order { 4 }
      description { "Lunch staples" }
      tax_group { "food" }
      association :business_type, factory: [:business_type, :cafe_bakery]
    end

    trait :smoothies do
      name { "Smoothies & Juices" }
      sort_order { 5 }
      description { "Blended drinks and fresh-pressed juices" }
      tax_group { "beverage" }
      association :business_type, factory: [:business_type, :cafe_bakery]
    end

    # ── Bar & Nightclub ───────────────────────────────────────

    trait :draft_beer do
      name { "Draft Beer" }
      sort_order { 1 }
      description { "On tap" }
      tax_group { "alcohol" }
      association :business_type, factory: [:business_type, :bar_nightclub]
    end

    trait :cocktails do
      name { "Cocktails" }
      sort_order { 2 }
      description { "Handcrafted cocktails" }
      tax_group { "alcohol" }
      association :business_type, factory: [:business_type, :bar_nightclub]
    end

    trait :spirits do
      name { "Spirits" }
      sort_order { 3 }
      description { "Neat, on the rocks, or mixed" }
      tax_group { "alcohol" }
      association :business_type, factory: [:business_type, :bar_nightclub]
    end

    trait :wine do
      name { "Wine" }
      sort_order { 4 }
      description { "By the glass" }
      tax_group { "alcohol" }
      association :business_type, factory: [:business_type, :bar_nightclub]
    end

    trait :bar_snacks do
      name { "Bar Snacks" }
      sort_order { 5 }
      description { "Late-night bites" }
      tax_group { "food" }
      association :business_type, factory: [:business_type, :bar_nightclub]
    end

    # ── Food Truck ────────────────────────────────────────────

    trait :tacos do
      name { "Tacos" }
      sort_order { 1 }
      description { "Street-style tacos" }
      tax_group { "food" }
      association :business_type, factory: [:business_type, :food_truck]
    end

    trait :burritos_bowls do
      name { "Burritos & Bowls" }
      sort_order { 2 }
      description { "Burritos, bowls, and quesadillas" }
      tax_group { "food" }
      association :business_type, factory: [:business_type, :food_truck]
    end

    trait :truck_sides_drinks do
      name { "Sides & Drinks" }
      sort_order { 3 }
      description { "Extras and beverages" }
      tax_group { "food" }
      association :business_type, factory: [:business_type, :food_truck]
    end

    # ── Fine Dining ───────────────────────────────────────────

    trait :first_course do
      name { "First Course" }
      sort_order { 1 }
      description { "Opening plates" }
      tax_group { "food" }
      association :business_type, factory: [:business_type, :fine_dining]
    end

    trait :main_course do
      name { "Main Course" }
      sort_order { 2 }
      description { "Chef's signature mains" }
      tax_group { "food" }
      association :business_type, factory: [:business_type, :fine_dining]
    end

    trait :fine_desserts do
      name { "Desserts & Petit Fours" }
      sort_order { 3 }
      description { "Sweet courses and cheese" }
      tax_group { "food" }
      association :business_type, factory: [:business_type, :fine_dining]
    end

    # ── Pizzeria ──────────────────────────────────────────────

    trait :pizzas do
      name { "Pizzas" }
      sort_order { 1 }
      description { "Hand-tossed pies" }
      tax_group { "food" }
      association :business_type, factory: [:business_type, :pizzeria]
    end

    trait :calzones do
      name { "Calzones & Stromboli" }
      sort_order { 2 }
      description { "Folded and rolled" }
      tax_group { "food" }
      association :business_type, factory: [:business_type, :pizzeria]
    end

    trait :pizza_sides_drinks do
      name { "Sides & Drinks" }
      sort_order { 3 }
      description { "Extras and beverages" }
      tax_group { "food" }
      association :business_type, factory: [:business_type, :pizzeria]
    end

    # ── Retail Clothing ───────────────────────────────────────

    trait :tops do
      name { "Tops" }
      sort_order { 1 }
      description { "T-shirts, shirts, and hoodies" }
      tax_group { "retail" }
      association :business_type, factory: [:business_type, :retail_clothing]
    end

    trait :bottoms do
      name { "Bottoms" }
      sort_order { 2 }
      description { "Jeans, pants, and shorts" }
      tax_group { "retail" }
      association :business_type, factory: [:business_type, :retail_clothing]
    end

    trait :outerwear do
      name { "Outerwear" }
      sort_order { 3 }
      description { "Jackets and vests" }
      tax_group { "retail" }
      association :business_type, factory: [:business_type, :retail_clothing]
    end

    trait :accessories do
      name { "Accessories" }
      sort_order { 4 }
      description { "Hats, belts, and scarves" }
      tax_group { "retail" }
      association :business_type, factory: [:business_type, :retail_clothing]
    end

    trait :footwear do
      name { "Footwear" }
      sort_order { 5 }
      description { "Shoes and boots" }
      tax_group { "retail" }
      association :business_type, factory: [:business_type, :retail_clothing]
    end

    # ── Retail General ────────────────────────────────────────

    trait :electronics do
      name { "Electronics" }
      sort_order { 1 }
      description { "Gadgets and accessories" }
      tax_group { "retail" }
      association :business_type, factory: [:business_type, :retail_general]
    end

    trait :home_kitchen do
      name { "Home & Kitchen" }
      sort_order { 2 }
      description { "Home décor and kitchen essentials" }
      tax_group { "retail" }
      association :business_type, factory: [:business_type, :retail_general]
    end

    trait :personal_care do
      name { "Personal Care" }
      sort_order { 3 }
      description { "Skincare and body care" }
      tax_group { "retail" }
      association :business_type, factory: [:business_type, :retail_general]
    end

    trait :office_supplies do
      name { "Office Supplies" }
      sort_order { 4 }
      description { "Desk and stationery" }
      tax_group { "retail" }
      association :business_type, factory: [:business_type, :retail_general]
    end

    trait :snacks_beverages do
      name { "Snacks & Beverages" }
      sort_order { 5 }
      description { "Grab-and-go food and drinks" }
      tax_group { "food" }
      association :business_type, factory: [:business_type, :retail_general]
    end

    # ── Salon & Spa ───────────────────────────────────────────

    trait :haircuts do
      name { "Haircuts" }
      sort_order { 1 }
      description { "Cuts and trims" }
      tax_group { "service" }
      association :business_type, factory: [:business_type, :salon_spa]
    end

    trait :color_services do
      name { "Color Services" }
      sort_order { 2 }
      description { "Color, highlights, and balayage" }
      tax_group { "service" }
      association :business_type, factory: [:business_type, :salon_spa]
    end

    trait :spa_treatments do
      name { "Spa Treatments" }
      sort_order { 3 }
      description { "Massage and facials" }
      tax_group { "service" }
      association :business_type, factory: [:business_type, :salon_spa]
    end

    trait :nail_services do
      name { "Nail Services" }
      sort_order { 4 }
      description { "Manicures and pedicures" }
      tax_group { "service" }
      association :business_type, factory: [:business_type, :salon_spa]
    end
  end
end
