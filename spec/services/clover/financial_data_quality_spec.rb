# frozen_string_literal: true

require "spec_helper"

# =============================================================================
# RED PHASE: Tests for financial data quality issues
#
# These tests verify fixes for discount zero-amount bugs, modifier tracking,
# payment validation, and refund total recalculation consistency.
# =============================================================================
RSpec.describe "Financial Data Quality" do
  before { stub_clover_credentials }

  let(:base_url) { "https://sandbox.dev.clover.com/v3/merchants/TEST_MERCHANT_ID" }

  # ============================================================================
  # 1. Discount Service: Always send calculated amount, never percentage-only
  # ============================================================================
  describe CloverSandboxSimulator::Services::Clover::DiscountService do
    let(:service) { described_class.new }

    describe "#apply_loyalty_discount — must send calculated amount" do
      let(:order_id) { "ORDER_LOYALTY" }

      it "sends amount (not percentage) to Clover API for Gold tier" do
        customer = { "visit_count" => 30 }

        # Stub the order fetch for calculate_total (needed to compute discount amount)
        stub_request(:get, "#{base_url}/orders/#{order_id}")
          .with(query: { expand: "lineItems,discounts,payments,customers" })
          .to_return(
            status: 200,
            body: {
              "id" => order_id,
              "lineItems" => {
                "elements" => [
                  { "id" => "LI1", "price" => 5000, "quantity" => 1 }
                ]
              }
            }.to_json,
            headers: { "Content-Type" => "application/json" }
          )

        # Expect the POST to include "amount" and NOT "percentage"
        stub_request(:post, "#{base_url}/orders/#{order_id}/discounts")
          .with { |request|
            body = JSON.parse(request.body)
            body.key?("amount") && !body.key?("percentage")
          }
          .to_return(
            status: 200,
            body: { id: "LD_LOYALTY", name: "Loyalty - Gold", amount: -750 }.to_json,
            headers: { "Content-Type" => "application/json" }
          )

        result = service.apply_loyalty_discount(order_id, customer: customer)

        expect(result).not_to be_nil
        expect(result["amount"]).to eq(-750)
      end

      it "calculates correct amount for Silver tier (10%)" do
        customer = { "visit_count" => 15 }

        stub_request(:get, "#{base_url}/orders/#{order_id}")
          .with(query: { expand: "lineItems,discounts,payments,customers" })
          .to_return(
            status: 200,
            body: {
              "id" => order_id,
              "lineItems" => {
                "elements" => [
                  { "id" => "LI1", "price" => 3000, "quantity" => 1 },
                  { "id" => "LI2", "price" => 2000, "quantity" => 1 }
                ]
              }
            }.to_json,
            headers: { "Content-Type" => "application/json" }
          )

        stub_request(:post, "#{base_url}/orders/#{order_id}/discounts")
          .with { |request|
            body = JSON.parse(request.body)
            body["amount"] == -500 # 10% of 5000 = 500
          }
          .to_return(
            status: 200,
            body: { id: "LD_LOYALTY", name: "Loyalty - Silver", amount: -500 }.to_json,
            headers: { "Content-Type" => "application/json" }
          )

        result = service.apply_loyalty_discount(order_id, customer: customer)

        expect(result).not_to be_nil
        expect(result["amount"]).to eq(-500)
      end
    end

    describe "#apply_promo_code — order-level percentage promo must send amount" do
      let(:order_id) { "ORDER_PROMO" }
      let(:valid_time) { Time.new(2026, 6, 15, 14, 0, 0) }

      it "sends calculated amount for percentage promo without max cap (SAVE10)" do
        stub_request(:post, "#{base_url}/orders/#{order_id}/discounts")
          .with { |request|
            body = JSON.parse(request.body)
            body.key?("amount") && !body.key?("percentage")
          }
          .to_return(
            status: 200,
            body: { id: "OD_PROMO", name: "Save 10%", amount: -500 }.to_json,
            headers: { "Content-Type" => "application/json" }
          )

        result = service.apply_promo_code(
          order_id,
          code: "SAVE10",
          order_total: 5000,
          current_time: valid_time
        )

        expect(result).not_to be_nil
        # Verify amount was sent, not percentage
        expect(WebMock).to have_requested(:post, "#{base_url}/orders/#{order_id}/discounts")
          .with { |request|
            body = JSON.parse(request.body)
            body.key?("amount") && !body.key?("percentage")
          }
      end
    end

    describe "#apply_promo_code — line-item percentage promo must send amount" do
      let(:order_id) { "ORDER_LI_PROMO" }
      let(:valid_time) { Time.new(2026, 6, 15, 14, 0, 0) }

      it "sends calculated amount for line-item percentage promo (HALFAPP)" do
        line_items = [
          {
            "id" => "LI1",
            "price" => 1200,
            "item" => { "categories" => { "elements" => [{ "name" => "Appetizers" }] }, "price" => 1200 }
          }
        ]

        stub_request(:post, "#{base_url}/orders/#{order_id}/line_items/LI1/discounts")
          .with { |request|
            body = JSON.parse(request.body)
            body.key?("amount") && !body.key?("percentage")
          }
          .to_return(
            status: 200,
            body: { id: "LID_PROMO", name: "Half Off Appetizers", amount: -600 }.to_json,
            headers: { "Content-Type" => "application/json" }
          )

        result = service.apply_promo_code(
          order_id,
          code: "HALFAPP",
          order_total: 1200,
          line_items: line_items,
          current_time: valid_time
        )

        expect(result).to be_an(Array)
        expect(result.first["amount"]).to eq(-600)
      end
    end

    describe "#apply_combo_discount — percentage combo on matching items must send amount" do
      let(:order_id) { "ORDER_COMBO" }

      it "sends calculated amount for percentage combo applied to matching items" do
        line_items = [
          { "id" => "LI1", "price" => 1499, "item" => { "name" => "Classic Burger", "category" => "Entrees" } },
          { "id" => "LI2", "price" => 499, "item" => { "name" => "French Fries", "category" => "Sides" } }
        ]

        combo = {
          "id" => "test_combo",
          "name" => "Burger & Fries Deal",
          "discount_type" => "percentage",
          "discount_value" => 20,
          "applies_to" => "matching_items",
          "required_components" => [
            { "category" => "Entrees", "quantity" => 1 },
            { "category" => "Sides", "quantity" => 1 }
          ]
        }

        # Each line item discount should have amount, not percentage
        stub_request(:post, "#{base_url}/orders/#{order_id}/line_items/LI1/discounts")
          .with { |request|
            body = JSON.parse(request.body)
            body.key?("amount") && !body.key?("percentage")
          }
          .to_return(
            status: 200,
            body: { id: "CD1", name: "Burger & Fries Deal", amount: -300 }.to_json,
            headers: { "Content-Type" => "application/json" }
          )

        stub_request(:post, "#{base_url}/orders/#{order_id}/line_items/LI2/discounts")
          .with { |request|
            body = JSON.parse(request.body)
            body.key?("amount") && !body.key?("percentage")
          }
          .to_return(
            status: 200,
            body: { id: "CD2", name: "Burger & Fries Deal", amount: -100 }.to_json,
            headers: { "Content-Type" => "application/json" }
          )

        result = service.apply_combo_discount(order_id, combo: combo, line_items: line_items)

        expect(result).to be_an(Array)
        expect(result.size).to eq(2)
      end
    end

    describe "#build_discount_payload safety net" do
      it "raises ArgumentError when percentage-only discount would be sent" do
        expect {
          service.send(
            :build_discount_payload,
            name: "Bad Discount",
            percentage: 15
            # No amount, no item_price — this would produce amount=0 in Clover
          )
        }.to raise_error(ArgumentError, /percentage-only.*amount.*0/)
      end

      it "allows percentage discount when item_price is provided" do
        payload = service.send(
          :build_discount_payload,
          name: "Good Discount",
          percentage: 15,
          item_price: 2000
        )

        expect(payload["amount"]).to eq(-300)
        expect(payload).not_to have_key("percentage")
      end

      it "allows fixed amount discount without item_price" do
        payload = service.send(
          :build_discount_payload,
          name: "Fixed Discount",
          amount: 500
        )

        expect(payload["amount"]).to eq(-500)
      end
    end

    describe "#apply_category_line_item_discounts — must pass item_price" do
      let(:order_id) { "ORDER_CAT" }

      it "sends calculated amount for percentage category discount" do
        line_items = [
          {
            "id" => "LI1",
            "price" => 1500,
            "item" => { "categories" => { "elements" => [{ "name" => "Drinks" }] }, "price" => 1500 }
          }
        ]

        stub_request(:post, "#{base_url}/orders/#{order_id}/line_items/LI1/discounts")
          .with { |request|
            body = JSON.parse(request.body)
            body.key?("amount") && !body.key?("percentage")
          }
          .to_return(
            status: 200,
            body: { id: "CLD1", name: "Drink Special", amount: -450 }.to_json,
            headers: { "Content-Type" => "application/json" }
          )

        result = service.apply_category_line_item_discounts(
          order_id,
          line_items: line_items,
          eligible_categories: ["Drinks"],
          discount_config: { name: "Drink Special", percentage: 30 }
        )

        expect(result.size).to eq(1)
        expect(result.first["amount"]).to eq(-450)
      end
    end
  end

  # ============================================================================
  # 2. Refund Service: recalculate_order_total must include modifier prices
  # ============================================================================
  describe CloverSandboxSimulator::Services::Clover::RefundService do
    let(:service) { described_class.new }

    describe "#recalculate_order_total" do
      it "includes modifier prices when recalculating after void" do
        order_id = "ORDER_REFUND_MODS"

        # Order with remaining items that have modifiers
        stub_request(:get, "#{base_url}/orders/#{order_id}?expand=lineItems,discounts")
          .to_return(
            status: 200,
            body: {
              "id" => order_id,
              "lineItems" => {
                "elements" => [
                  {
                    "id" => "LI1",
                    "price" => 1499,
                    "quantity" => 1,
                    "modifications" => {
                      "elements" => [
                        { "id" => "MOD1", "price" => 150 }, # Extra Cheese
                        { "id" => "MOD2", "price" => 200 }  # Bacon
                      ]
                    }
                  }
                ]
              },
              "discounts" => { "elements" => [] }
            }.to_json,
            headers: { "Content-Type" => "application/json" }
          )

        # Expect the updated total to include modifier prices
        # 1499 (base) + 150 (cheese) + 200 (bacon) = 1849
        stub_request(:post, "#{base_url}/orders/#{order_id}")
          .with { |request|
            body = JSON.parse(request.body)
            body["total"] == 1849
          }
          .to_return(
            status: 200,
            body: { "id" => order_id, "total" => 1849 }.to_json,
            headers: { "Content-Type" => "application/json" }
          )

        service.send(:recalculate_order_total, order_id)

        expect(WebMock).to have_requested(:post, "#{base_url}/orders/#{order_id}")
          .with { |request|
            body = JSON.parse(request.body)
            body["total"] == 1849
          }
      end

      it "handles items with modifiers AND discounts correctly" do
        order_id = "ORDER_REFUND_BOTH"

        stub_request(:get, "#{base_url}/orders/#{order_id}?expand=lineItems,discounts")
          .to_return(
            status: 200,
            body: {
              "id" => order_id,
              "lineItems" => {
                "elements" => [
                  {
                    "id" => "LI1",
                    "price" => 2000,
                    "quantity" => 1,
                    "modifications" => {
                      "elements" => [
                        { "id" => "MOD1", "price" => 200 }
                      ]
                    }
                  }
                ]
              },
              "discounts" => {
                "elements" => [
                  { "amount" => -500 } # $5 discount
                ]
              }
            }.to_json,
            headers: { "Content-Type" => "application/json" }
          )

        # Expected: 2000 + 200 (mod) - 500 (discount) = 1700
        stub_request(:post, "#{base_url}/orders/#{order_id}")
          .with { |request|
            body = JSON.parse(request.body)
            body["total"] == 1700
          }
          .to_return(
            status: 200,
            body: { "id" => order_id, "total" => 1700 }.to_json,
            headers: { "Content-Type" => "application/json" }
          )

        service.send(:recalculate_order_total, order_id)

        expect(WebMock).to have_requested(:post, "#{base_url}/orders/#{order_id}")
          .with { |request|
            body = JSON.parse(request.body)
            body["total"] == 1700
          }
      end
    end
  end

  # ============================================================================
  # 3. Order Service: calculate_total validation against Clover's own total
  # ============================================================================
  describe CloverSandboxSimulator::Services::Clover::OrderService do
    let(:service) { described_class.new }

    describe "#calculate_total" do
      it "includes modification prices in total" do
        stub_request(:get, "#{base_url}/orders/ORDER1")
          .with(query: { expand: "lineItems,discounts,payments,customers" })
          .to_return(
            status: 200,
            body: {
              "id" => "ORDER1",
              "lineItems" => {
                "elements" => [
                  {
                    "id" => "LI1",
                    "price" => 1499,
                    "quantity" => 1,
                    "modifications" => {
                      "elements" => [
                        { "id" => "M1", "price" => 150 },
                        { "id" => "M2", "price" => 200 }
                      ]
                    }
                  },
                  {
                    "id" => "LI2",
                    "price" => 999,
                    "quantity" => 1
                  }
                ]
              },
              "discounts" => { "elements" => [] }
            }.to_json,
            headers: { "Content-Type" => "application/json" }
          )

        total = service.calculate_total("ORDER1")

        # 1499 + 150 + 200 + 999 = 2848
        expect(total).to eq(2848)
      end
    end

    describe "#validate_total" do
      it "logs a warning when calculated total differs from Clover total" do
        order_data = {
          "id" => "ORDER_VAL",
          "total" => 3000,
          "lineItems" => {
            "elements" => [
              { "id" => "LI1", "price" => 2500, "quantity" => 1 }
            ]
          },
          "discounts" => { "elements" => [] }
        }

        stub_request(:get, "#{base_url}/orders/ORDER_VAL")
          .with(query: { expand: "lineItems,discounts,payments,customers" })
          .to_return(
            status: 200,
            body: order_data.to_json,
            headers: { "Content-Type" => "application/json" }
          )

        # Calculated total (2500) != Clover total (3000) — likely hidden modifiers
        result = service.validate_total("ORDER_VAL")

        expect(result[:calculated]).to eq(2500)
        expect(result[:clover_total]).to eq(3000)
        expect(result[:delta]).to eq(500)
        expect(result[:match]).to be false
      end

      it "confirms match when totals agree" do
        order_data = {
          "id" => "ORDER_OK",
          "total" => 2500,
          "lineItems" => {
            "elements" => [
              { "id" => "LI1", "price" => 2500, "quantity" => 1 }
            ]
          },
          "discounts" => { "elements" => [] }
        }

        stub_request(:get, "#{base_url}/orders/ORDER_OK")
          .with(query: { expand: "lineItems,discounts,payments,customers" })
          .to_return(
            status: 200,
            body: order_data.to_json,
            headers: { "Content-Type" => "application/json" }
          )

        result = service.validate_total("ORDER_OK")

        expect(result[:calculated]).to eq(2500)
        expect(result[:clover_total]).to eq(2500)
        expect(result[:delta]).to eq(0)
        expect(result[:match]).to be true
      end
    end
  end
end
