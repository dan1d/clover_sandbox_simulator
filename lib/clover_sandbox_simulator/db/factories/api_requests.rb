# frozen_string_literal: true

FactoryBot.define do
  factory :api_request, class: "CloverSandboxSimulator::Models::ApiRequest" do
    http_method { "GET" }
    sequence(:url) { |n| "https://sandbox.dev.clover.com/v3/merchants/TESTMERCHANT/orders/ORDER#{n}" }
    response_status { 200 }
    duration_ms { 150 }
    resource_type { "Order" }
    request_payload { {} }
    response_payload { {} }

    # ── HTTP method traits ─────────────────────────────────────

    trait :get do
      http_method { "GET" }
      response_status { 200 }
    end

    trait :post do
      http_method { "POST" }
      response_status { 201 }
      request_payload { { name: "New Item", price: 999 } }
    end

    trait :put do
      http_method { "PUT" }
      response_status { 200 }
      request_payload { { name: "Updated Item" } }
    end

    trait :delete do
      http_method { "DELETE" }
      response_status { 204 }
      response_payload { {} }
    end

    # ── Status traits ──────────────────────────────────────────

    trait :error do
      response_status { 500 }
      error_message { "Internal Server Error" }
      response_payload { { message: "Internal Server Error" } }
    end

    trait :not_found do
      response_status { 404 }
      error_message { "Not Found" }
      response_payload { { message: "Not Found" } }
    end

    trait :rate_limited do
      response_status { 429 }
      error_message { "Too Many Requests" }
      response_payload { { message: "Rate limit exceeded. Retry after 60s." } }
    end

    trait :unauthorized do
      response_status { 401 }
      error_message { "Unauthorized" }
      response_payload { { message: "Invalid API token" } }
    end

    # ── Performance traits ─────────────────────────────────────

    trait :slow do
      duration_ms { 2500 }
    end

    trait :fast do
      duration_ms { 25 }
    end

    # ── Resource traits ────────────────────────────────────────

    trait :order_resource do
      resource_type { "Order" }
      sequence(:resource_id) { |n| "ORDER#{n}" }
      sequence(:url) { |n| "https://sandbox.dev.clover.com/v3/merchants/TESTMERCHANT/orders/ORDER#{n}" }
    end

    trait :item_resource do
      resource_type { "Item" }
      sequence(:resource_id) { |n| "ITEM#{n}" }
      sequence(:url) { |n| "https://sandbox.dev.clover.com/v3/merchants/TESTMERCHANT/items/ITEM#{n}" }
    end

    trait :payment_resource do
      resource_type { "Payment" }
      sequence(:resource_id) { |n| "PAY#{n}" }
      sequence(:url) { |n| "https://sandbox.dev.clover.com/v3/merchants/TESTMERCHANT/payments/PAY#{n}" }
    end
  end
end
