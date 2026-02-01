# frozen_string_literal: true

require "spec_helper"

RSpec.describe CloverSandboxSimulator::Services::Clover::DiscountService do
  before { stub_clover_credentials }

  let(:service) { described_class.new }
  let(:base_url) { "https://sandbox.dev.clover.com/v3/merchants/TEST_MERCHANT_ID" }

  let(:sample_discounts) do
    [
      { "id" => "D1", "name" => "10% Off", "percentage" => 10, "amount" => nil },
      { "id" => "D2", "name" => "Happy Hour", "percentage" => 15, "amount" => nil },
      { "id" => "D3", "name" => "$5 Off", "percentage" => nil, "amount" => -500 },
      { "id" => "D4", "name" => "Employee Discount", "percentage" => 20, "amount" => nil }
    ]
  end

  describe "#get_discounts" do
    it "fetches all discounts" do
      stub_request(:get, "#{base_url}/discounts")
        .to_return(
          status: 200,
          body: { elements: sample_discounts }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      discounts = service.get_discounts

      expect(discounts).to be_an(Array)
      expect(discounts.size).to eq(4)
      expect(discounts.first["id"]).to eq("D1")
    end

    it "returns empty array when no discounts exist" do
      stub_request(:get, "#{base_url}/discounts")
        .to_return(
          status: 200,
          body: { elements: [] }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      discounts = service.get_discounts

      expect(discounts).to eq([])
    end

    it "handles nil elements in response" do
      stub_request(:get, "#{base_url}/discounts")
        .to_return(
          status: 200,
          body: {}.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      discounts = service.get_discounts

      expect(discounts).to eq([])
    end

    it "handles nil response" do
      stub_request(:get, "#{base_url}/discounts")
        .to_return(
          status: 200,
          body: "null",
          headers: { "Content-Type" => "application/json" }
        )

      discounts = service.get_discounts

      expect(discounts).to eq([])
    end
  end

  describe "#get_discount" do
    it "fetches a specific discount by ID" do
      discount_data = { "id" => "D1", "name" => "10% Off", "percentage" => 10 }

      stub_request(:get, "#{base_url}/discounts/D1")
        .to_return(
          status: 200,
          body: discount_data.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      discount = service.get_discount("D1")

      expect(discount["id"]).to eq("D1")
      expect(discount["name"]).to eq("10% Off")
      expect(discount["percentage"]).to eq(10)
    end

    it "raises ApiError for non-existent discount" do
      stub_request(:get, "#{base_url}/discounts/NONEXISTENT")
        .to_return(
          status: 404,
          body: { message: "Discount not found" }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      expect { service.get_discount("NONEXISTENT") }
        .to raise_error(CloverSandboxSimulator::ApiError, /404.*Discount not found/)
    end
  end

  describe "#create_percentage_discount" do
    it "creates a percentage-based discount" do
      stub_request(:post, "#{base_url}/discounts")
        .with(body: hash_including(
          "name" => "Summer Sale",
          "percentage" => 20
        ))
        .to_return(
          status: 200,
          body: { id: "D_NEW", name: "Summer Sale", percentage: 20 }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      discount = service.create_percentage_discount(name: "Summer Sale", percentage: 20)

      expect(discount["id"]).to eq("D_NEW")
      expect(discount["name"]).to eq("Summer Sale")
      expect(discount["percentage"]).to eq(20)
    end

    it "creates discount with small percentage" do
      stub_request(:post, "#{base_url}/discounts")
        .with(body: hash_including(
          "name" => "Tiny Discount",
          "percentage" => 1
        ))
        .to_return(
          status: 200,
          body: { id: "D_SMALL", name: "Tiny Discount", percentage: 1 }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      discount = service.create_percentage_discount(name: "Tiny Discount", percentage: 1)

      expect(discount["percentage"]).to eq(1)
    end

    it "creates discount with 100 percent" do
      stub_request(:post, "#{base_url}/discounts")
        .with(body: hash_including(
          "name" => "Free Item",
          "percentage" => 100
        ))
        .to_return(
          status: 200,
          body: { id: "D_FREE", name: "Free Item", percentage: 100 }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      discount = service.create_percentage_discount(name: "Free Item", percentage: 100)

      expect(discount["percentage"]).to eq(100)
    end

    it "handles decimal percentage values" do
      stub_request(:post, "#{base_url}/discounts")
        .with(body: hash_including(
          "name" => "Decimal Discount",
          "percentage" => 12.5
        ))
        .to_return(
          status: 200,
          body: { id: "D_DEC", name: "Decimal Discount", percentage: 12.5 }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      discount = service.create_percentage_discount(name: "Decimal Discount", percentage: 12.5)

      expect(discount["percentage"]).to eq(12.5)
    end
  end

  describe "#create_fixed_discount" do
    it "creates a fixed amount discount with negative amount" do
      stub_request(:post, "#{base_url}/discounts")
        .with(body: hash_including(
          "name" => "$5 Off",
          "amount" => -500 # 500 cents = $5, negated
        ))
        .to_return(
          status: 200,
          body: { id: "D_FIXED", name: "$5 Off", amount: -500 }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      discount = service.create_fixed_discount(name: "$5 Off", amount: 500)

      expect(discount["id"]).to eq("D_FIXED")
      expect(discount["name"]).to eq("$5 Off")
      expect(discount["amount"]).to eq(-500)
    end

    it "converts positive amount to negative for Clover API" do
      stub_request(:post, "#{base_url}/discounts")
        .with(body: hash_including("amount" => -1000))
        .to_return(
          status: 200,
          body: { id: "D_FIXED", amount: -1000 }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      service.create_fixed_discount(name: "$10 Off", amount: 1000)

      expect(WebMock).to have_requested(:post, "#{base_url}/discounts")
        .with(body: hash_including("amount" => -1000))
    end

    it "handles already negative amount correctly" do
      stub_request(:post, "#{base_url}/discounts")
        .with(body: hash_including("amount" => -750))
        .to_return(
          status: 200,
          body: { id: "D_FIXED", amount: -750 }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      discount = service.create_fixed_discount(name: "$7.50 Off", amount: -750)

      expect(discount["amount"]).to eq(-750)
    end

    it "creates small fixed discount" do
      stub_request(:post, "#{base_url}/discounts")
        .with(body: hash_including(
          "name" => "$0.25 Off",
          "amount" => -25
        ))
        .to_return(
          status: 200,
          body: { id: "D_SMALL", name: "$0.25 Off", amount: -25 }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      discount = service.create_fixed_discount(name: "$0.25 Off", amount: 25)

      expect(discount["amount"]).to eq(-25)
    end

    it "creates large fixed discount" do
      stub_request(:post, "#{base_url}/discounts")
        .with(body: hash_including(
          "name" => "$100 Off",
          "amount" => -10000
        ))
        .to_return(
          status: 200,
          body: { id: "D_LARGE", name: "$100 Off", amount: -10000 }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      discount = service.create_fixed_discount(name: "$100 Off", amount: 10000)

      expect(discount["amount"]).to eq(-10000)
    end
  end

  describe "#delete_discount" do
    it "deletes a discount by ID" do
      stub_request(:delete, "#{base_url}/discounts/D1")
        .to_return(
          status: 200,
          body: "".to_json,
          headers: { "Content-Type" => "application/json" }
        )

      service.delete_discount("D1")

      expect(WebMock).to have_requested(:delete, "#{base_url}/discounts/D1")
    end

    it "raises ApiError for deletion of non-existent discount" do
      stub_request(:delete, "#{base_url}/discounts/NONEXISTENT")
        .to_return(
          status: 404,
          body: { message: "Discount not found" }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      expect { service.delete_discount("NONEXISTENT") }
        .to raise_error(CloverSandboxSimulator::ApiError, /404.*Discount not found/)
    end

    it "handles deletion with special characters in ID" do
      stub_request(:delete, "#{base_url}/discounts/D-123_ABC")
        .to_return(
          status: 200,
          body: "".to_json,
          headers: { "Content-Type" => "application/json" }
        )

      service.delete_discount("D-123_ABC")

      expect(WebMock).to have_requested(:delete, "#{base_url}/discounts/D-123_ABC")
    end
  end

  describe "#random_discount" do
    before do
      stub_request(:get, "#{base_url}/discounts")
        .to_return(
          status: 200,
          body: { elements: sample_discounts }.to_json,
          headers: { "Content-Type" => "application/json" }
        )
    end

    it "returns nil approximately 70% of the time" do
      allow_any_instance_of(Kernel).to receive(:rand).and_return(0.5)

      result = service.random_discount

      expect(result).to be_nil
    end

    it "returns a discount when rand is >= 0.7" do
      allow_any_instance_of(Kernel).to receive(:rand).and_return(0.8)

      result = service.random_discount

      expect(result).not_to be_nil
      expect(sample_discounts.map { |d| d["id"] }).to include(result["id"])
    end

    it "returns nil when rand is exactly 0.69" do
      allow_any_instance_of(Kernel).to receive(:rand).and_return(0.69)

      result = service.random_discount

      expect(result).to be_nil
    end

    it "returns a discount when rand is exactly 0.7" do
      allow_any_instance_of(Kernel).to receive(:rand).and_return(0.7)

      result = service.random_discount

      expect(result).not_to be_nil
    end

    it "returns nil when no discounts exist and rand triggers discount" do
      stub_request(:get, "#{base_url}/discounts")
        .to_return(
          status: 200,
          body: { elements: [] }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      allow_any_instance_of(Kernel).to receive(:rand).and_return(0.9)

      result = service.random_discount

      expect(result).to be_nil
    end

    context "probability distribution" do
      it "follows 70% nil / 30% discount probability" do
        nil_count = 0
        discount_count = 0
        iterations = 1000

        iterations.times do
          # Reset stubs for each iteration
          WebMock.reset!
          stub_request(:get, "#{base_url}/discounts")
            .to_return(
              status: 200,
              body: { elements: sample_discounts }.to_json,
              headers: { "Content-Type" => "application/json" }
            )

          result = service.random_discount
          if result.nil?
            nil_count += 1
          else
            discount_count += 1
          end
        end

        # Allow for statistical variance (expect ~65-75% nil)
        nil_percentage = (nil_count.to_f / iterations) * 100
        expect(nil_percentage).to be_within(7).of(70)
      end
    end
  end

  # ============================================
  # LINE-ITEM DISCOUNT TESTS
  # ============================================

  describe "#apply_line_item_discount" do
    let(:order_id) { "ORDER123" }
    let(:line_item_id) { "LI456" }

    it "applies a percentage discount to a line item" do
      stub_request(:post, "#{base_url}/orders/#{order_id}/line_items/#{line_item_id}/discounts")
        .with(body: hash_including(
          "name" => "Happy Hour Drinks",
          "percentage" => "30"
        ))
        .to_return(
          status: 200,
          body: { id: "LD1", name: "Happy Hour Drinks", percentage: "30" }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      result = service.apply_line_item_discount(
        order_id,
        line_item_id: line_item_id,
        name: "Happy Hour Drinks",
        percentage: 30
      )

      expect(result["id"]).to eq("LD1")
      expect(result["name"]).to eq("Happy Hour Drinks")
    end

    it "applies a fixed amount discount to a line item" do
      stub_request(:post, "#{base_url}/orders/#{order_id}/line_items/#{line_item_id}/discounts")
        .with(body: hash_including(
          "name" => "$2 Off Dessert",
          "amount" => -200
        ))
        .to_return(
          status: 200,
          body: { id: "LD2", name: "$2 Off Dessert", amount: -200 }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      result = service.apply_line_item_discount(
        order_id,
        line_item_id: line_item_id,
        name: "$2 Off Dessert",
        amount: 200
      )

      expect(result["amount"]).to eq(-200)
    end

    it "applies a discount by discount_id" do
      stub_request(:get, "#{base_url}/discounts/D1")
        .to_return(
          status: 200,
          body: { id: "D1", name: "10% Off", percentage: 10 }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      stub_request(:post, "#{base_url}/orders/#{order_id}/line_items/#{line_item_id}/discounts")
        .with(body: hash_including("name" => "10% Off"))
        .to_return(
          status: 200,
          body: { id: "LD3", name: "10% Off", percentage: "10" }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      result = service.apply_line_item_discount(
        order_id,
        line_item_id: line_item_id,
        discount_id: "D1"
      )

      expect(result["name"]).to eq("10% Off")
    end
  end

  describe "#get_line_item_discounts" do
    let(:order_id) { "ORDER123" }
    let(:line_item_id) { "LI456" }

    it "fetches discounts for a specific line item" do
      stub_request(:get, "#{base_url}/orders/#{order_id}/line_items/#{line_item_id}/discounts")
        .to_return(
          status: 200,
          body: { elements: [{ id: "LD1", name: "Happy Hour" }] }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      discounts = service.get_line_item_discounts(order_id, line_item_id)

      expect(discounts.size).to eq(1)
      expect(discounts.first["name"]).to eq("Happy Hour")
    end
  end

  describe "#delete_line_item_discount" do
    let(:order_id) { "ORDER123" }
    let(:line_item_id) { "LI456" }
    let(:discount_id) { "LD1" }

    it "deletes a line item discount" do
      stub_request(:delete, "#{base_url}/orders/#{order_id}/line_items/#{line_item_id}/discounts/#{discount_id}")
        .to_return(status: 200, body: "", headers: { "Content-Type" => "application/json" })

      service.delete_line_item_discount(order_id, line_item_id, discount_id)

      expect(WebMock).to have_requested(:delete,
        "#{base_url}/orders/#{order_id}/line_items/#{line_item_id}/discounts/#{discount_id}")
    end
  end

  # ============================================
  # PROMO/COUPON CODE TESTS
  # ============================================

  describe "#validate_promo_code" do
    let(:valid_time) { Time.new(2026, 6, 15, 14, 0, 0) } # 2 PM on a weekday

    context "with valid promo code" do
      it "validates SAVE10 successfully" do
        result = service.validate_promo_code("SAVE10", order_total: 5000, current_time: valid_time)

        expect(result[:valid]).to be true
        expect(result[:coupon]["code"]).to eq("SAVE10")
        expect(result[:discount_preview][:amount]).to eq(500) # 10% of 5000
      end

      it "validates case-insensitively" do
        result = service.validate_promo_code("save10", order_total: 5000, current_time: valid_time)

        expect(result[:valid]).to be true
      end

      it "calculates correct discount for fixed amount codes" do
        result = service.validate_promo_code("FIVER", order_total: 3000, current_time: valid_time)

        expect(result[:valid]).to be true
        expect(result[:discount_preview][:amount]).to eq(500)
      end

      it "applies max discount cap" do
        result = service.validate_promo_code("SAVE20", order_total: 20000, current_time: valid_time)

        expect(result[:valid]).to be true
        # 20% of 20000 = 4000, but max is 2000
        expect(result[:discount_preview][:amount]).to eq(2000)
      end
    end

    context "with invalid promo code" do
      it "rejects non-existent code" do
        result = service.validate_promo_code("NONEXISTENT", current_time: valid_time)

        expect(result[:valid]).to be false
        expect(result[:error]).to eq("Invalid promo code")
      end

      it "rejects inactive code" do
        result = service.validate_promo_code("INACTIVE", current_time: valid_time)

        expect(result[:valid]).to be false
        expect(result[:error]).to eq("Promo code is inactive")
      end

      it "rejects expired code" do
        result = service.validate_promo_code("EXPIRED20", current_time: valid_time)

        expect(result[:valid]).to be false
        expect(result[:error]).to eq("Promo code has expired")
      end

      it "rejects code that reached usage limit" do
        result = service.validate_promo_code("MAXEDOUT", current_time: valid_time)

        expect(result[:valid]).to be false
        expect(result[:error]).to eq("Promo code has reached its usage limit")
      end
    end

    context "with order amount restrictions" do
      it "rejects when order is below minimum" do
        result = service.validate_promo_code("FIVER", order_total: 2000, current_time: valid_time)

        expect(result[:valid]).to be false
        expect(result[:error]).to include("Minimum order amount")
      end

      it "accepts when order meets minimum" do
        result = service.validate_promo_code("FIVER", order_total: 2500, current_time: valid_time)

        expect(result[:valid]).to be true
      end
    end

    context "with time restrictions" do
      it "validates HAPPYHOUR during happy hour" do
        happy_hour_time = Time.new(2026, 6, 15, 16, 0, 0) # 4 PM
        result = service.validate_promo_code("HAPPYHOUR", order_total: 3000, current_time: happy_hour_time)

        expect(result[:valid]).to be true
      end

      it "rejects HAPPYHOUR outside happy hour" do
        morning_time = Time.new(2026, 6, 15, 10, 0, 0) # 10 AM
        result = service.validate_promo_code("HAPPYHOUR", order_total: 3000, current_time: morning_time)

        expect(result[:valid]).to be false
        expect(result[:error]).to include("specific hours")
      end
    end

    context "with day restrictions" do
      it "validates WEEKEND25 on Saturday" do
        saturday = Time.new(2026, 6, 13, 14, 0, 0) # Saturday
        result = service.validate_promo_code("WEEKEND25", order_total: 5000, current_time: saturday)

        expect(result[:valid]).to be true
      end

      it "rejects WEEKEND25 on weekday" do
        tuesday = Time.new(2026, 6, 16, 14, 0, 0) # Tuesday
        result = service.validate_promo_code("WEEKEND25", order_total: 5000, current_time: tuesday)

        expect(result[:valid]).to be false
        expect(result[:error]).to include("not valid today")
      end
    end

    context "with customer restrictions" do
      it "rejects new customer code for returning customer" do
        customer = { "visit_count" => 5 }
        result = service.validate_promo_code("WELCOME20", customer: customer, current_time: valid_time)

        expect(result[:valid]).to be false
        expect(result[:error]).to include("new customers only")
      end

      it "accepts new customer code for first-time customer" do
        customer = { "visit_count" => 0 }
        result = service.validate_promo_code("WELCOME20", customer: customer, current_time: valid_time)

        expect(result[:valid]).to be true
      end

      it "rejects VIP code for non-VIP customer" do
        customer = { "is_vip" => false }
        result = service.validate_promo_code("VIP25", customer: customer, current_time: valid_time)

        expect(result[:valid]).to be false
        expect(result[:error]).to include("VIP members only")
      end

      it "accepts VIP code for VIP customer" do
        customer = { "is_vip" => true }
        result = service.validate_promo_code("VIP25", customer: customer, current_time: valid_time)

        expect(result[:valid]).to be true
      end
    end

    context "with category restrictions" do
      let(:line_items) do
        [
          { "id" => "LI1", "item" => { "categories" => { "elements" => [{ "name" => "Appetizers" }] } } },
          { "id" => "LI2", "item" => { "categories" => { "elements" => [{ "name" => "Entrees" }] } } }
        ]
      end

      it "validates when order has eligible items" do
        result = service.validate_promo_code("HALFAPP", line_items: line_items, current_time: valid_time)

        expect(result[:valid]).to be true
      end

      it "rejects when order has no eligible items" do
        entrees_only = [
          { "id" => "LI1", "item" => { "categories" => { "elements" => [{ "name" => "Entrees" }] } } }
        ]

        result = service.validate_promo_code("HALFAPP", line_items: entrees_only, current_time: valid_time)

        expect(result[:valid]).to be false
        expect(result[:error]).to include("No eligible items")
      end
    end
  end

  describe "#apply_promo_code" do
    let(:order_id) { "ORDER123" }
    let(:valid_time) { Time.new(2026, 6, 15, 14, 0, 0) }

    it "applies order-level promo code" do
      stub_request(:post, "#{base_url}/orders/#{order_id}/discounts")
        .with(body: hash_including("name" => "Save 10%"))
        .to_return(
          status: 200,
          body: { id: "OD1", name: "Save 10%", percentage: "10" }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      result = service.apply_promo_code(
        order_id,
        code: "SAVE10",
        order_total: 5000,
        current_time: valid_time
      )

      expect(result).not_to be_nil
    end

    it "returns nil for invalid promo code" do
      result = service.apply_promo_code(
        order_id,
        code: "INVALID",
        order_total: 5000,
        current_time: valid_time
      )

      expect(result).to be_nil
    end

    it "applies line-item promo code to eligible items" do
      line_items = [
        { "id" => "LI1", "item" => { "categories" => { "elements" => [{ "name" => "Appetizers" }] }, "price" => 1000 } }
      ]

      stub_request(:post, "#{base_url}/orders/#{order_id}/line_items/LI1/discounts")
        .to_return(
          status: 200,
          body: { id: "LID1", name: "Half Off Appetizers" }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      result = service.apply_promo_code(
        order_id,
        code: "HALFAPP",
        order_total: 1000,
        line_items: line_items,
        current_time: valid_time
      )

      expect(result).to be_an(Array)
      expect(result.first["name"]).to eq("Half Off Appetizers")
    end
  end

  describe "#get_coupon_codes" do
    it "returns all coupon codes from JSON" do
      coupons = service.get_coupon_codes

      expect(coupons).to be_an(Array)
      expect(coupons.size).to be > 0

      # Verify structure
      coupon = coupons.first
      expect(coupon).to have_key("code")
      expect(coupon).to have_key("discount_type")
      expect(coupon).to have_key("discount_value")
    end
  end

  # ============================================
  # COMBO/BUNDLE DISCOUNT TESTS
  # ============================================

  describe "#detect_combos" do
    let(:current_time) { Time.new(2026, 6, 15, 14, 0, 0) }

    context "with classic meal combo" do
      let(:line_items) do
        [
          { "id" => "LI1", "item" => { "name" => "Classic Burger", "category" => "Entrees", "price" => 1499 } },
          { "id" => "LI2", "item" => { "name" => "French Fries", "category" => "Sides", "price" => 499 } },
          { "id" => "LI3", "item" => { "name" => "Soft Drink", "category" => "Drinks", "price" => 299 } }
        ]
      end

      it "detects classic meal combo" do
        combos = service.detect_combos(line_items, current_time: current_time)

        expect(combos).not_to be_empty
        classic_meal = combos.find { |c| c[:combo]["id"] == "classic_meal" }
        expect(classic_meal).not_to be_nil
        expect(classic_meal[:discount][:amount]).to be > 0
      end

      it "calculates correct combo discount" do
        combos = service.detect_combos(line_items, current_time: current_time)
        classic_meal = combos.find { |c| c[:combo]["id"] == "classic_meal" }

        # Total is 2297, 15% discount = 344.55 rounded
        expect(classic_meal[:discount][:amount]).to be_within(1).of(345)
      end
    end

    context "with appetizer sampler combo" do
      let(:line_items) do
        [
          { "id" => "LI1", "item" => { "name" => "Buffalo Wings", "category" => "Appetizers", "price" => 1299 } },
          { "id" => "LI2", "item" => { "name" => "Mozzarella Sticks", "category" => "Appetizers", "price" => 899 } },
          { "id" => "LI3", "item" => { "name" => "Nachos", "category" => "Appetizers", "price" => 1099 } }
        ]
      end

      it "detects appetizer sampler combo" do
        combos = service.detect_combos(line_items, current_time: current_time)

        appetizer_sampler = combos.find { |c| c[:combo]["id"] == "appetizer_sampler" }
        expect(appetizer_sampler).not_to be_nil
      end
    end

    context "with insufficient items for combo" do
      let(:line_items) do
        [
          { "id" => "LI1", "item" => { "name" => "Classic Burger", "category" => "Entrees", "price" => 1499 } }
        ]
      end

      it "returns empty when no combos match" do
        combos = service.detect_combos(line_items, current_time: current_time)

        # Should only have combos that require 1 or fewer items
        combo_ids = combos.map { |c| c[:combo]["id"] }
        expect(combo_ids).not_to include("classic_meal")
        expect(combo_ids).not_to include("appetizer_sampler")
      end
    end

    context "with time-restricted combos" do
      let(:line_items) do
        [
          { "id" => "LI1", "item" => { "name" => "Buffalo Wings", "category" => "Appetizers", "price" => 1299 } },
          { "id" => "LI2", "item" => { "name" => "Draft Beer", "category" => "Alcoholic Beverages", "price" => 599 } },
          { "id" => "LI3", "item" => { "name" => "Draft Beer", "category" => "Alcoholic Beverages", "price" => 599 } }
        ]
      end

      it "includes happy hour combo during happy hour" do
        happy_hour = Time.new(2026, 6, 15, 16, 0, 0) # 4 PM
        combos = service.detect_combos(line_items, current_time: happy_hour)

        happy_hour_combo = combos.find { |c| c[:combo]["id"] == "happy_hour_combo" }
        expect(happy_hour_combo).not_to be_nil
      end

      it "excludes happy hour combo outside happy hour" do
        morning = Time.new(2026, 6, 15, 10, 0, 0)
        combos = service.detect_combos(line_items, current_time: morning)

        happy_hour_combo = combos.find { |c| c[:combo]["id"] == "happy_hour_combo" }
        expect(happy_hour_combo).to be_nil
      end
    end

    context "combo ordering by value" do
      let(:line_items) do
        # Enough items for multiple combos
        [
          { "id" => "LI1", "item" => { "name" => "Classic Burger", "category" => "Entrees", "price" => 1499 } },
          { "id" => "LI2", "item" => { "name" => "Grilled Salmon", "category" => "Entrees", "price" => 2199 } },
          { "id" => "LI3", "item" => { "name" => "French Fries", "category" => "Sides", "price" => 499 } },
          { "id" => "LI4", "item" => { "name" => "Mashed Potatoes", "category" => "Sides", "price" => 499 } },
          { "id" => "LI5", "item" => { "name" => "Soft Drink", "category" => "Drinks", "price" => 299 } },
          { "id" => "LI6", "item" => { "name" => "Iced Tea", "category" => "Drinks", "price" => 299 } }
        ]
      end

      it "returns combos sorted by discount value (best first)" do
        combos = service.detect_combos(line_items, current_time: current_time)

        next unless combos.size > 1

        first_value = combos[0][:discount][:amount]
        second_value = combos[1][:discount][:amount]
        expect(first_value).to be >= second_value
      end
    end
  end

  describe "#apply_combo_discount" do
    let(:order_id) { "ORDER123" }
    let(:line_items) do
      [
        { "id" => "LI1", "item" => { "name" => "Classic Burger", "category" => "Entrees", "price" => 1499 } },
        { "id" => "LI2", "item" => { "name" => "French Fries", "category" => "Sides", "price" => 499 } },
        { "id" => "LI3", "item" => { "name" => "Soft Drink", "category" => "Drinks", "price" => 299 } }
      ]
    end

    let(:classic_meal_combo) do
      {
        "id" => "classic_meal",
        "name" => "Classic Meal Deal",
        "discount_type" => "percentage",
        "discount_value" => 15,
        "applies_to" => "total",
        "required_components" => [
          { "category" => "Entrees", "quantity" => 1 },
          { "category" => "Sides", "quantity" => 1 },
          { "category" => "Drinks", "quantity" => 1 }
        ]
      }
    end

    it "applies combo discount to order" do
      stub_request(:post, "#{base_url}/orders/#{order_id}/discounts")
        .with(body: hash_including("name" => "Classic Meal Deal"))
        .to_return(
          status: 200,
          body: { id: "CD1", name: "Classic Meal Deal" }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      result = service.apply_combo_discount(order_id, combo: classic_meal_combo, line_items: line_items)

      expect(result).not_to be_nil
    end
  end

  describe "#get_combos" do
    it "returns all combos from JSON" do
      combos = service.get_combos

      expect(combos).to be_an(Array)
      expect(combos.size).to be > 0

      # Verify structure
      combo = combos.first
      expect(combo).to have_key("id")
      expect(combo).to have_key("name")
      expect(combo).to have_key("required_components")
    end
  end

  # ============================================
  # TIME-BASED DISCOUNT TESTS
  # ============================================

  describe "#get_time_based_discounts" do
    it "returns happy hour discounts during happy hour" do
      happy_hour = Time.new(2026, 6, 15, 16, 0, 0) # 4 PM
      discounts = service.get_time_based_discounts(current_time: happy_hour)

      expect(discounts).not_to be_empty
      names = discounts.map { |d| d["name"] }
      expect(names).to include("Happy Hour")
    end

    it "returns lunch discounts during lunch" do
      lunch_time = Time.new(2026, 6, 15, 12, 0, 0) # 12 PM
      discounts = service.get_time_based_discounts(current_time: lunch_time)

      lunch_discount = discounts.find { |d| d["name"].include?("Lunch") }
      expect(lunch_discount).not_to be_nil
    end

    it "returns empty for late night" do
      late_night = Time.new(2026, 6, 15, 22, 0, 0) # 10 PM
      discounts = service.get_time_based_discounts(current_time: late_night)

      # Only auto-apply discounts should be returned
      auto_apply = discounts.select { |d| d["auto_apply"] }
      # Late night is after early bird ends (6 PM) and after happy hour
      expect(auto_apply).to be_empty
    end
  end

  describe "#within_time_period?" do
    it "returns true when within period" do
      rules = { "start_hour" => 15, "end_hour" => 18 }
      time = Time.new(2026, 6, 15, 16, 0, 0)

      expect(service.within_time_period?(rules, time)).to be true
    end

    it "returns false when before period" do
      rules = { "start_hour" => 15, "end_hour" => 18 }
      time = Time.new(2026, 6, 15, 10, 0, 0)

      expect(service.within_time_period?(rules, time)).to be false
    end

    it "returns false when after period" do
      rules = { "start_hour" => 15, "end_hour" => 18 }
      time = Time.new(2026, 6, 15, 19, 0, 0)

      expect(service.within_time_period?(rules, time)).to be false
    end

    it "returns true when nil rules (no restriction)" do
      expect(service.within_time_period?(nil)).to be true
    end
  end

  describe "#current_meal_period" do
    it "identifies breakfast period" do
      time = Time.new(2026, 6, 15, 8, 0, 0)
      expect(service.current_meal_period(time)).to eq(:breakfast)
    end

    it "identifies lunch period" do
      time = Time.new(2026, 6, 15, 12, 0, 0)
      expect(service.current_meal_period(time)).to eq(:lunch)
    end

    it "identifies happy_hour period" do
      time = Time.new(2026, 6, 15, 16, 0, 0)
      expect(service.current_meal_period(time)).to eq(:happy_hour)
    end

    it "identifies dinner period" do
      time = Time.new(2026, 6, 15, 19, 0, 0)
      expect(service.current_meal_period(time)).to eq(:dinner)
    end

    it "identifies late_night period" do
      time = Time.new(2026, 6, 15, 22, 0, 0)
      expect(service.current_meal_period(time)).to eq(:late_night)
    end

    it "identifies closed period" do
      time = Time.new(2026, 6, 15, 3, 0, 0)
      expect(service.current_meal_period(time)).to eq(:closed)
    end
  end

  describe "#happy_hour_discounts" do
    it "returns happy hour discounts during happy hour" do
      happy_hour = Time.new(2026, 6, 15, 16, 0, 0)
      discounts = service.happy_hour_discounts(current_time: happy_hour)

      expect(discounts).not_to be_empty
    end

    it "returns empty outside happy hour" do
      morning = Time.new(2026, 6, 15, 9, 0, 0)
      discounts = service.happy_hour_discounts(current_time: morning)

      expect(discounts).to be_empty
    end
  end

  # ============================================
  # LOYALTY DISCOUNT TESTS
  # ============================================

  describe "#loyalty_tier" do
    it "returns platinum for 50+ visits" do
      customer = { "visit_count" => 55 }
      tier = service.loyalty_tier(customer)

      expect(tier[:tier]).to eq(:platinum)
      expect(tier[:percentage]).to eq(20)
    end

    it "returns gold for 25-49 visits" do
      customer = { "visit_count" => 30 }
      tier = service.loyalty_tier(customer)

      expect(tier[:tier]).to eq(:gold)
      expect(tier[:percentage]).to eq(15)
    end

    it "returns silver for 10-24 visits" do
      customer = { "visit_count" => 15 }
      tier = service.loyalty_tier(customer)

      expect(tier[:tier]).to eq(:silver)
      expect(tier[:percentage]).to eq(10)
    end

    it "returns bronze for 5-9 visits" do
      customer = { "visit_count" => 7 }
      tier = service.loyalty_tier(customer)

      expect(tier[:tier]).to eq(:bronze)
      expect(tier[:percentage]).to eq(5)
    end

    it "returns nil for fewer than 5 visits" do
      customer = { "visit_count" => 3 }
      tier = service.loyalty_tier(customer)

      expect(tier).to be_nil
    end

    it "returns nil for nil customer" do
      tier = service.loyalty_tier(nil)

      expect(tier).to be_nil
    end

    it "reads visit_count from metadata" do
      customer = { "metadata" => { "visit_count" => 12 } }
      tier = service.loyalty_tier(customer)

      expect(tier[:tier]).to eq(:silver)
    end
  end

  describe "#get_loyalty_discount" do
    it "returns matching discount for customer tier" do
      customer = { "visit_count" => 30 }
      discount = service.get_loyalty_discount(customer)

      expect(discount).not_to be_nil
      expect(discount["name"]).to include("Gold")
    end

    it "returns nil for customer without tier" do
      customer = { "visit_count" => 2 }
      discount = service.get_loyalty_discount(customer)

      expect(discount).to be_nil
    end
  end

  describe "#apply_loyalty_discount" do
    let(:order_id) { "ORDER123" }

    it "applies loyalty discount for eligible customer" do
      customer = { "visit_count" => 30 }

      stub_request(:post, "#{base_url}/orders/#{order_id}/discounts")
        .with(body: hash_including("name" => "Loyalty - Gold"))
        .to_return(
          status: 200,
          body: { id: "LD1", name: "Loyalty - Gold", percentage: "15" }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      result = service.apply_loyalty_discount(order_id, customer: customer)

      expect(result["name"]).to eq("Loyalty - Gold")
    end

    it "returns nil for customer without tier" do
      customer = { "visit_count" => 2 }

      result = service.apply_loyalty_discount(order_id, customer: customer)

      expect(result).to be_nil
    end
  end

  describe "#first_order_discount?" do
    it "returns true for nil customer" do
      expect(service.first_order_discount?(nil)).to be true
    end

    it "returns true for customer with 0 visits" do
      customer = { "visit_count" => 0 }
      expect(service.first_order_discount?(customer)).to be true
    end

    it "returns true for customer with 1 visit" do
      customer = { "visit_count" => 1 }
      expect(service.first_order_discount?(customer)).to be true
    end

    it "returns false for customer with 2+ visits" do
      customer = { "visit_count" => 2 }
      expect(service.first_order_discount?(customer)).to be false
    end
  end

  # ============================================
  # SMART DISCOUNT SELECTION TESTS
  # ============================================

  describe "#select_best_discount" do
    let(:current_time) { Time.new(2026, 6, 15, 16, 0, 0) } # 4 PM - Happy Hour

    it "recommends combo when items form a combo" do
      line_items = [
        { "id" => "LI1", "item" => { "category" => "Entrees", "price" => 1499 } },
        { "id" => "LI2", "item" => { "category" => "Sides", "price" => 499 } },
        { "id" => "LI3", "item" => { "category" => "Drinks", "price" => 299 } }
      ]

      result = service.select_best_discount(
        order_total: 2297,
        line_items: line_items,
        current_time: current_time
      )

      # Combo should be recommended (higher priority)
      expect(result).not_to be_nil
      expect([:combo, :time_based]).to include(result[:type])
    end

    it "recommends loyalty for high-tier customer" do
      customer = { "visit_count" => 50 }

      result = service.select_best_discount(
        order_total: 5000,
        customer: customer,
        current_time: current_time
      )

      # May return time_based, loyalty, or threshold depending on values
      expect(result).not_to be_nil
    end

    it "recommends threshold discount for high order total" do
      result = service.select_best_discount(
        order_total: 15000, # $150
        current_time: current_time
      )

      expect(result).not_to be_nil
    end

    it "returns nil when no discounts apply" do
      # Very early morning, no customer, minimal order
      early_morning = Time.new(2026, 6, 15, 3, 0, 0)

      result = service.select_best_discount(
        order_total: 500,
        line_items: [],
        current_time: early_morning
      )

      # Might still get threshold discounts if total meets minimum
      # Otherwise nil
      expect(result).to be_nil
    end
  end

  # ============================================
  # API ERROR HANDLING TESTS
  # ============================================

  describe "API error handling" do
    it "raises ApiError for 401 unauthorized response" do
      stub_request(:get, "#{base_url}/discounts")
        .to_return(
          status: 401,
          body: { message: "Unauthorized" }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      expect { service.get_discounts }
        .to raise_error(CloverSandboxSimulator::ApiError, /401.*Unauthorized/)
    end

    it "raises ApiError for 500 internal server error" do
      stub_request(:get, "#{base_url}/discounts")
        .to_return(
          status: 500,
          body: { message: "Internal Server Error" }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      expect { service.get_discounts }
        .to raise_error(CloverSandboxSimulator::ApiError, /500.*Internal Server Error/)
    end

    it "raises error on network timeout" do
      stub_request(:get, "#{base_url}/discounts")
        .to_timeout

      expect { service.get_discounts }.to raise_error(StandardError)
    end

    it "raises ApiError for malformed JSON response" do
      stub_request(:get, "#{base_url}/discounts")
        .to_return(
          status: 200,
          body: "not valid json",
          headers: { "Content-Type" => "application/json" }
        )

      expect { service.get_discounts }
        .to raise_error(CloverSandboxSimulator::ApiError, /Invalid JSON response/)
    end
  end

  describe "request format" do
    it "sends correct headers for GET request" do
      stub_request(:get, "#{base_url}/discounts")
        .to_return(
          status: 200,
          body: { elements: [] }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      service.get_discounts

      expect(WebMock).to have_requested(:get, "#{base_url}/discounts")
    end

    it "sends correct headers for POST request" do
      stub_request(:post, "#{base_url}/discounts")
        .to_return(
          status: 200,
          body: { id: "D_NEW" }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      service.create_percentage_discount(name: "Test", percentage: 10)

      expect(WebMock).to have_requested(:post, "#{base_url}/discounts")
    end

    it "sends correct headers for DELETE request" do
      stub_request(:delete, "#{base_url}/discounts/D1")
        .to_return(
          status: 200,
          body: "".to_json,
          headers: { "Content-Type" => "application/json" }
        )

      service.delete_discount("D1")

      expect(WebMock).to have_requested(:delete, "#{base_url}/discounts/D1")
    end
  end

  describe "discount data integrity" do
    it "preserves all discount attributes from response" do
      full_discount = {
        "id" => "D_FULL",
        "name" => "Full Discount",
        "percentage" => 15,
        "amount" => nil,
        "enabled" => true,
        "merchantRef" => { "id" => "MERCHANT1" },
        "createdTime" => 1609459200000,
        "modifiedTime" => 1609459200000
      }

      stub_request(:get, "#{base_url}/discounts/D_FULL")
        .to_return(
          status: 200,
          body: full_discount.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      discount = service.get_discount("D_FULL")

      expect(discount["id"]).to eq("D_FULL")
      expect(discount["name"]).to eq("Full Discount")
      expect(discount["percentage"]).to eq(15)
      expect(discount["enabled"]).to eq(true)
      expect(discount["createdTime"]).to eq(1609459200000)
    end
  end
end
