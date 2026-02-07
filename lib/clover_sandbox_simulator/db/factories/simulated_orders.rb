# frozen_string_literal: true

require "securerandom"

FactoryBot.define do
  factory :simulated_order, class: "CloverSandboxSimulator::Models::SimulatedOrder" do
    sequence(:clover_merchant_id) { |n| "MERCHANT#{n}" }
    status { "open" }
    business_date { Date.today }
    subtotal { 0 }
    tax_amount { 0 }
    tip_amount { 0 }
    discount_amount { 0 }
    total { 0 }
    metadata { {} }

    trait :paid do
      status { "paid" }
      sequence(:clover_order_id) { |n| "ORD#{n}#{SecureRandom.hex(4).upcase}" }
      subtotal { 2500 }        # cents
      tax_amount { 222 }       # cents
      tip_amount { 450 }       # cents
      discount_amount { 0 }    # cents
      total { 3172 }           # cents — subtotal + tax + tip - discount
      meal_period { "lunch" }
      dining_option { "HERE" }
    end

    trait :refunded do
      status { "refunded" }
      sequence(:clover_order_id) { |n| "ORD#{n}#{SecureRandom.hex(4).upcase}" }
      subtotal { 1800 }
      tax_amount { 160 }
      tip_amount { 0 }
      discount_amount { 0 }
      total { 1960 }
      meal_period { "dinner" }
      dining_option { "HERE" }
    end

    trait :failed do
      status { "failed" }
      subtotal { 0 }
      tax_amount { 0 }
      tip_amount { 0 }
      total { 0 }
      metadata { { "error" => "Payment declined" } }
    end

    trait :with_business_type do
      association :business_type, factory: [:business_type, :restaurant]
    end

    # Convenience: a paid order with associated payment
    trait :with_payment do
      paid

      after(:create) do |order|
        create(:simulated_payment, :success, simulated_order: order, amount: order.total)
      end
    end

    # Convenience: a paid order with a split payment (cash + card)
    trait :with_split_payment do
      paid
      total { 4000 }
      subtotal { 3400 }
      tax_amount { 302 }
      tip_amount { 298 }

      after(:create) do |order|
        half = order.total / 2
        create(:simulated_payment, :success, :cash_tender, simulated_order: order, amount: half)
        create(:simulated_payment, :success, :credit_tender, simulated_order: order, amount: order.total - half)
      end
    end

    # Meal-period traits
    trait :breakfast_order do
      meal_period { "breakfast" }
      dining_option { "HERE" }
    end

    trait :lunch_order do
      meal_period { "lunch" }
      dining_option { "HERE" }
    end

    trait :dinner_order do
      meal_period { "dinner" }
      dining_option { "HERE" }
    end

    trait :late_night_order do
      meal_period { "late_night" }
      dining_option { "HERE" }
    end

    # Dining-option traits
    trait :dine_in do
      dining_option { "HERE" }
    end

    trait :takeout do
      dining_option { "TO_GO" }
    end

    trait :delivery do
      dining_option { "DELIVERY" }
    end
  end
end
