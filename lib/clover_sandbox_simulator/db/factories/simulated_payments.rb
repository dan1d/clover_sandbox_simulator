# frozen_string_literal: true

FactoryBot.define do
  factory :simulated_payment, class: "CloverSandboxSimulator::Models::SimulatedPayment" do
    association :simulated_order
    tender_name { "Cash" }
    amount { 1500 }       # cents
    tip_amount { 0 }      # cents
    tax_amount { 0 }      # cents
    status { "pending" }
    payment_type { nil }

    # ── Status traits ──────────────────────────────────────────

    trait :success do
      status { "paid" }
      sequence(:clover_payment_id) { |n| "PAY#{n}#{SecureRandom.hex(4).upcase}" }
    end

    trait :failed do
      status { "failed" }
    end

    trait :refunded do
      status { "refunded" }
      sequence(:clover_payment_id) { |n| "PAY#{n}#{SecureRandom.hex(4).upcase}" }
    end

    # ── Tender traits ──────────────────────────────────────────

    trait :cash_tender do
      tender_name { "Cash" }
      payment_type { "cash" }
    end

    trait :credit_tender do
      tender_name { "Credit Card" }
      payment_type { "credit" }
    end

    trait :debit_tender do
      tender_name { "Debit Card" }
      payment_type { "debit" }
    end

    trait :gift_card_tender do
      tender_name { "Gift Card" }
      payment_type { "gift_card" }
    end

    # ── Split payment trait ────────────────────────────────────
    # Marks this payment as part of a split (amount is a portion of the total)
    trait :split do
      status { "paid" }
      sequence(:clover_payment_id) { |n| "PAY#{n}#{SecureRandom.hex(4).upcase}" }
      amount { 750 }  # half of a typical order
    end
  end
end
