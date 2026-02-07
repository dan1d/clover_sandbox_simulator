# frozen_string_literal: true

FactoryBot.define do
  factory :daily_summary, class: "CloverSandboxSimulator::Models::DailySummary" do
    sequence(:merchant_id) { |n| "MERCHANT#{n}" }
    business_date { Date.today }
    order_count { 0 }
    payment_count { 0 }
    refund_count { 0 }
    total_revenue { 0 }      # cents
    total_tax { 0 }           # cents
    total_tips { 0 }          # cents
    total_discounts { 0 }     # cents
    breakdown { {} }

    # A realistic busy-day summary
    trait :busy_day do
      order_count { 85 }
      payment_count { 90 }
      refund_count { 2 }
      total_revenue { 425_000 }    # $4,250.00
      total_tax { 37_719 }         # $377.19
      total_tips { 63_750 }        # $637.50
      total_discounts { 12_500 }   # $125.00
      breakdown do
        {
          by_meal_period: { "breakfast" => 15, "lunch" => 40, "dinner" => 30 },
          by_dining_option: { "HERE" => 55, "TO_GO" => 20, "DELIVERY" => 10 },
          by_tender: { "Cash" => 25, "Credit Card" => 55, "Debit Card" => 10 },
          revenue_by_meal_period: { "breakfast" => 45_000, "lunch" => 180_000, "dinner" => 200_000 },
          revenue_by_dining_option: { "HERE" => 280_000, "TO_GO" => 95_000, "DELIVERY" => 50_000 }
        }
      end
    end

    # A slow-day summary
    trait :slow_day do
      order_count { 12 }
      payment_count { 12 }
      refund_count { 0 }
      total_revenue { 48_000 }     # $480.00
      total_tax { 4_260 }          # $42.60
      total_tips { 7_200 }         # $72.00
      total_discounts { 0 }
      breakdown do
        {
          by_meal_period: { "lunch" => 5, "dinner" => 7 },
          by_dining_option: { "HERE" => 8, "TO_GO" => 4 },
          by_tender: { "Cash" => 4, "Credit Card" => 8 },
          revenue_by_meal_period: { "lunch" => 18_000, "dinner" => 30_000 },
          revenue_by_dining_option: { "HERE" => 32_000, "TO_GO" => 16_000 }
        }
      end
    end
  end
end
