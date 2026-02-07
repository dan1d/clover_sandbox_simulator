# frozen_string_literal: true

require "spec_helper"

RSpec.describe CloverSandboxSimulator::Models::DailySummary, :db do
  describe "validations" do
    it "requires merchant_id" do
      summary = build(:daily_summary, merchant_id: nil)
      expect(summary).not_to be_valid
      expect(summary.errors[:merchant_id]).to include("can't be blank")
    end

    it "requires business_date" do
      summary = build(:daily_summary, business_date: nil)
      expect(summary).not_to be_valid
    end

    it "enforces uniqueness of merchant_id + business_date" do
      create(:daily_summary, merchant_id: "M1", business_date: Date.today)
      dup = build(:daily_summary, merchant_id: "M1", business_date: Date.today)
      expect(dup).not_to be_valid
    end

    it "allows the same date for different merchants" do
      create(:daily_summary, merchant_id: "M1", business_date: Date.today)
      expect(build(:daily_summary, merchant_id: "M2", business_date: Date.today)).to be_valid
    end
  end

  describe "scopes" do
    before do
      create(:daily_summary, merchant_id: "M1", business_date: Date.today, total_revenue: 5000)
      create(:daily_summary, merchant_id: "M1", business_date: Date.yesterday, total_revenue: 3000)
      create(:daily_summary, merchant_id: "M2", business_date: Date.today, total_revenue: 7000)
    end

    it ".for_merchant filters by merchant" do
      expect(described_class.for_merchant("M1").count).to eq(2)
    end

    it ".on_date filters by date" do
      expect(described_class.on_date(Date.today).count).to eq(2)
    end

    it ".today returns today's summaries" do
      expect(described_class.today.count).to eq(2)
    end

    it ".between_dates filters date range" do
      expect(described_class.between_dates(Date.yesterday, Date.today).count).to eq(3)
    end

    it ".recent returns summaries within N days (default 7)" do
      expect(described_class.recent.count).to eq(3)
      expect(described_class.recent(1).count).to eq(3)
    end
  end

  describe ".generate_for!" do
    before do
      create(:simulated_order, :paid, clover_merchant_id: "M1",
             total: 2500, tax_amount: 200, tip_amount: 300, discount_amount: 100,
             meal_period: "lunch", dining_option: "HERE")
      create(:simulated_order, :paid, clover_merchant_id: "M1",
             total: 1500, tax_amount: 100, tip_amount: 200, discount_amount: 0,
             meal_period: "dinner", dining_option: "TO_GO")
      create(:simulated_order, :refunded, clover_merchant_id: "M1", total: 500)

      CloverSandboxSimulator::Models::SimulatedOrder.where(status: "paid").find_each do |o|
        create(:simulated_payment, :success, :cash_tender, simulated_order: o, amount: o.total)
      end
    end

    it "aggregates order data correctly" do
      summary = described_class.generate_for!("M1", Date.today)

      expect(summary).to be_persisted
      expect(summary.order_count).to eq(2)
      expect(summary.payment_count).to eq(2)
      expect(summary.refund_count).to eq(1)
      expect(summary.total_revenue).to eq(4000)
      expect(summary.total_tax).to eq(300)
      expect(summary.total_tips).to eq(500)
      expect(summary.total_discounts).to eq(100)
    end

    it "includes breakdown by meal period and dining option" do
      summary = described_class.generate_for!("M1", Date.today)

      expect(summary.breakdown["by_meal_period"]).to include("lunch" => 1, "dinner" => 1)
      expect(summary.breakdown["by_dining_option"]).to include("HERE" => 1, "TO_GO" => 1)
      expect(summary.breakdown["by_tender"]).to include("Cash" => 2)
    end

    it "is idempotent — updates existing summary" do
      described_class.generate_for!("M1", Date.today)
      expect { described_class.generate_for!("M1", Date.today) }.not_to change { described_class.count }
    end

    it "handles merchant with no orders" do
      summary = described_class.generate_for!("EMPTY_MERCHANT", Date.today)
      expect(summary.order_count).to eq(0)
      expect(summary.total_revenue).to eq(0)
    end
  end

  describe "#total_revenue_dollars" do
    it "converts cents to dollars" do
      summary = build(:daily_summary, :busy_day)
      expect(summary.total_revenue_dollars).to eq(4250.0)
    end

    it "handles nil" do
      summary = build(:daily_summary, total_revenue: nil)
      expect(summary.total_revenue_dollars).to eq(0.0)
    end
  end
end
