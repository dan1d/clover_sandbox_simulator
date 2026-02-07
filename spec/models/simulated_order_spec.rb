# frozen_string_literal: true

require "spec_helper"

RSpec.describe CloverSandboxSimulator::Models::SimulatedOrder, :db do
  describe "validations" do
    it "requires clover_merchant_id" do
      order = build(:simulated_order, clover_merchant_id: nil)
      expect(order).not_to be_valid
      expect(order.errors[:clover_merchant_id]).to include("can't be blank")
    end

    it "requires status" do
      order = build(:simulated_order, status: nil)
      expect(order).not_to be_valid
      expect(order.errors[:status]).to include("can't be blank")
    end

    it "requires business_date" do
      order = build(:simulated_order, business_date: nil)
      expect(order).not_to be_valid
      expect(order.errors[:business_date]).to include("can't be blank")
    end

    it "allows optional business_type" do
      order = create(:simulated_order)
      expect(order.business_type).to be_nil
      expect(order).to be_persisted
    end
  end

  describe "associations" do
    it "belongs_to business_type (optional)" do
      order = create(:simulated_order, :with_business_type)
      expect(order.business_type).to be_a(CloverSandboxSimulator::Models::BusinessType)
    end

    it "has_many simulated_payments with cascade delete" do
      order = create(:simulated_order, :with_payment)
      expect(order.simulated_payments.count).to eq(1)
      expect { order.destroy }.to change { CloverSandboxSimulator::Models::SimulatedPayment.count }.by(-1)
    end
  end

  describe "status values" do
    it "creates paid orders" do
      order = create(:simulated_order, :paid)
      expect(order.status).to eq("paid")
      expect(order.total).to be > 0
      expect(order.clover_order_id).to be_present
    end

    it "creates refunded orders" do
      order = create(:simulated_order, :refunded)
      expect(order.status).to eq("refunded")
      expect(order.total).to be > 0
    end

    it "creates failed orders" do
      order = create(:simulated_order, :failed)
      expect(order.status).to eq("failed")
      expect(order.metadata).to include("error" => "Payment declined")
    end
  end

  describe "scopes" do
    before do
      create(:simulated_order, :paid, clover_merchant_id: "M1", meal_period: "lunch", dining_option: "HERE")
      create(:simulated_order, status: "open", clover_merchant_id: "M1", meal_period: "dinner", dining_option: "TO_GO")
      create(:simulated_order, :paid, clover_merchant_id: "M2", business_date: Date.yesterday, meal_period: "breakfast", dining_option: "DELIVERY")
      # Override :refunded trait defaults (meal_period: "dinner", dining_option: "HERE")
      # to nil so this order doesn't pollute the meal_period/dining_option scope assertions.
      create(:simulated_order, :refunded, clover_merchant_id: "M1", meal_period: nil, dining_option: nil)
    end

    it ".today returns today's orders" do
      expect(described_class.today.count).to eq(3)
    end

    it ".successful returns paid orders" do
      expect(described_class.successful.count).to eq(2)
    end

    it ".open_orders returns open orders" do
      expect(described_class.open_orders.count).to eq(1)
    end

    it ".refunded returns refunded orders" do
      expect(described_class.refunded.count).to eq(1)
    end

    it ".for_merchant filters by merchant ID" do
      expect(described_class.for_merchant("M1").count).to eq(3)
      expect(described_class.for_merchant("M2").count).to eq(1)
    end

    it ".for_meal_period filters by period" do
      expect(described_class.for_meal_period("lunch").count).to eq(1)
      expect(described_class.for_meal_period("dinner").count).to eq(1)
    end

    it ".for_dining_option filters by option" do
      expect(described_class.for_dining_option("HERE").count).to eq(1)
      expect(described_class.for_dining_option("TO_GO").count).to eq(1)
    end

    it ".on_date filters by specific date" do
      expect(described_class.on_date(Date.yesterday).count).to eq(1)
    end

    it ".between_dates filters date range" do
      expect(described_class.between_dates(Date.yesterday, Date.today).count).to eq(4)
    end
  end

  describe "payment associations" do
    it ":with_payment creates an order with one payment" do
      order = create(:simulated_order, :with_payment)
      expect(order.simulated_payments.count).to eq(1)
      expect(order.simulated_payments.first.status).to eq("SUCCESS")
      expect(order.simulated_payments.first.amount).to eq(order.total)
    end

    it ":with_split_payment creates an order with two payments summing to total" do
      order = create(:simulated_order, :with_split_payment)
      expect(order.simulated_payments.count).to eq(2)
      total_paid = order.simulated_payments.sum(&:amount)
      expect(total_paid).to eq(order.total)
    end
  end

  describe "#total_dollars / #subtotal_dollars" do
    it "converts cents to dollars" do
      order = build(:simulated_order, total: 1550, subtotal: 1200)
      expect(order.total_dollars).to eq(15.50)
      expect(order.subtotal_dollars).to eq(12.0)
    end

    it "handles nil" do
      order = build(:simulated_order, total: nil, subtotal: nil)
      expect(order.total_dollars).to eq(0.0)
      expect(order.subtotal_dollars).to eq(0.0)
    end
  end
end
