# frozen_string_literal: true

require "spec_helper"

# These specs require a live PostgreSQL database (clover_simulator_test).
# They are tagged with :db so database_cleaner wraps each example in a transaction.
RSpec.describe "Models", :db do
  # Convenience aliases
  let(:bt_class) { CloverSandboxSimulator::Models::BusinessType }
  let(:cat_class) { CloverSandboxSimulator::Models::Category }
  let(:item_class) { CloverSandboxSimulator::Models::Item }
  let(:order_class) { CloverSandboxSimulator::Models::SimulatedOrder }
  let(:payment_class) { CloverSandboxSimulator::Models::SimulatedPayment }
  let(:api_class) { CloverSandboxSimulator::Models::ApiRequest }
  let(:summary_class) { CloverSandboxSimulator::Models::DailySummary }

  # ---------- BusinessType ----------
  describe CloverSandboxSimulator::Models::BusinessType do
    it "validates key presence and uniqueness" do
      bt = bt_class.create!(key: "restaurant", name: "Restaurant", industry: "food")
      expect(bt).to be_persisted

      dup = bt_class.new(key: "restaurant", name: "Another")
      expect(dup).not_to be_valid
      expect(dup.errors[:key]).to include("has already been taken")
    end

    it "validates name presence" do
      bt = bt_class.new(key: "test", name: nil)
      expect(bt).not_to be_valid
      expect(bt.errors[:name]).to include("can't be blank")
    end

    describe "scopes" do
      before do
        bt_class.create!(key: "restaurant", name: "Restaurant", industry: "food")
        bt_class.create!(key: "clothing", name: "Clothing Store", industry: "retail")
        bt_class.create!(key: "salon", name: "Salon", industry: "service")
      end

      it ".food_types returns food industry" do
        expect(bt_class.food_types.pluck(:key)).to eq(["restaurant"])
      end

      it ".retail_types returns retail industry" do
        expect(bt_class.retail_types.pluck(:key)).to eq(["clothing"])
      end

      it ".service_types returns service industry" do
        expect(bt_class.service_types.pluck(:key)).to eq(["salon"])
      end
    end

    it ".find_by_key! finds by key" do
      bt_class.create!(key: "restaurant", name: "Restaurant")
      expect(bt_class.find_by_key!("restaurant").name).to eq("Restaurant")
    end

    it "has_many categories with cascade delete" do
      bt = bt_class.create!(key: "rest", name: "Rest")
      cat_class.create!(business_type: bt, name: "Appetizers")
      expect { bt.destroy }.to change { cat_class.count }.by(-1)
    end
  end

  # ---------- Category ----------
  describe CloverSandboxSimulator::Models::Category do
    let!(:bt) { bt_class.create!(key: "rest", name: "Restaurant") }

    it "validates name unique per business_type" do
      cat_class.create!(business_type: bt, name: "Appetizers")
      dup = cat_class.new(business_type: bt, name: "Appetizers")
      expect(dup).not_to be_valid
    end

    it "allows same name in different business_types" do
      bt2 = bt_class.create!(key: "retail", name: "Retail")
      cat_class.create!(business_type: bt, name: "Specials")
      expect(cat_class.new(business_type: bt2, name: "Specials")).to be_valid
    end

    it "orders by sort_order by default" do
      cat_class.create!(business_type: bt, name: "Desserts", sort_order: 3)
      cat_class.create!(business_type: bt, name: "Appetizers", sort_order: 1)
      cat_class.create!(business_type: bt, name: "Entrees", sort_order: 2)
      expect(cat_class.pluck(:name)).to eq(["Appetizers", "Entrees", "Desserts"])
    end

    it "cascades delete to items" do
      cat = cat_class.create!(business_type: bt, name: "Apps")
      item_class.create!(category: cat, name: "Wings", price: 1299)
      expect { cat.destroy }.to change { item_class.count }.by(-1)
    end
  end

  # ---------- Item ----------
  describe CloverSandboxSimulator::Models::Item do
    let!(:bt) { bt_class.create!(key: "rest", name: "Restaurant") }
    let!(:cat) { cat_class.create!(business_type: bt, name: "Appetizers") }

    it "validates price is non-negative integer" do
      expect(item_class.new(category: cat, name: "X", price: -1)).not_to be_valid
      expect(item_class.new(category: cat, name: "X", price: 0)).to be_valid
      expect(item_class.new(category: cat, name: "X", price: 999)).to be_valid
    end

    it "validates name unique per category" do
      item_class.create!(category: cat, name: "Wings", price: 1299)
      dup = item_class.new(category: cat, name: "Wings", price: 999)
      expect(dup).not_to be_valid
    end

    describe "scopes" do
      before do
        item_class.create!(category: cat, name: "Wings", price: 1299, active: true)
        item_class.create!(category: cat, name: "Old Item", price: 500, active: false)
      end

      it ".active returns active items" do
        expect(item_class.active.pluck(:name)).to eq(["Wings"])
      end

      it ".inactive returns inactive items" do
        expect(item_class.inactive.pluck(:name)).to eq(["Old Item"])
      end

      it ".for_business_type filters by business type key" do
        expect(item_class.for_business_type("rest").count).to eq(2)
        expect(item_class.for_business_type("nonexistent").count).to eq(0)
      end
    end

    it "#price_dollars converts cents to dollars" do
      item = item_class.new(price: 1299)
      expect(item.price_dollars).to eq(12.99)
    end
  end

  # ---------- SimulatedOrder ----------
  describe CloverSandboxSimulator::Models::SimulatedOrder do
    it "validates required fields" do
      order = order_class.new
      expect(order).not_to be_valid
      expect(order.errors[:clover_merchant_id]).to include("can't be blank")
      expect(order.errors[:business_date]).to include("can't be blank")
    end

    it "allows optional business_type" do
      order = order_class.create!(
        clover_merchant_id: "M1",
        business_date: Date.today,
        total: 5000
      )
      expect(order.business_type).to be_nil
      expect(order).to be_persisted
    end

    describe "scopes" do
      before do
        order_class.create!(clover_merchant_id: "M1", business_date: Date.today, status: "paid", total: 2000, meal_period: "lunch")
        order_class.create!(clover_merchant_id: "M1", business_date: Date.today, status: "open", total: 1000, meal_period: "dinner")
        order_class.create!(clover_merchant_id: "M2", business_date: Date.yesterday, status: "paid", total: 3000)
      end

      it ".today returns today's orders" do
        expect(order_class.today.count).to eq(2)
      end

      it ".successful returns paid orders" do
        expect(order_class.successful.count).to eq(2)
      end

      it ".for_merchant filters by merchant" do
        expect(order_class.for_merchant("M1").count).to eq(2)
        expect(order_class.for_merchant("M2").count).to eq(1)
      end

      it ".for_meal_period filters by period" do
        expect(order_class.for_meal_period("lunch").count).to eq(1)
      end

      it ".on_date filters by date" do
        expect(order_class.on_date(Date.yesterday).count).to eq(1)
      end
    end

    it "cascades delete to payments" do
      order = order_class.create!(clover_merchant_id: "M1", business_date: Date.today)
      payment_class.create!(simulated_order: order, tender_name: "Cash", amount: 1000)
      expect { order.destroy }.to change { payment_class.count }.by(-1)
    end
  end

  # ---------- SimulatedPayment ----------
  describe CloverSandboxSimulator::Models::SimulatedPayment do
    let!(:order) { order_class.create!(clover_merchant_id: "M1", business_date: Date.today) }

    it "validates tender_name presence" do
      p = payment_class.new(simulated_order: order, tender_name: nil, amount: 100)
      expect(p).not_to be_valid
    end

    it "validates amount is integer" do
      p = payment_class.new(simulated_order: order, tender_name: "Cash", amount: 1500)
      expect(p).to be_valid
    end

    describe "scopes" do
      before do
        payment_class.create!(simulated_order: order, tender_name: "Cash", amount: 1000, status: "paid")
        payment_class.create!(simulated_order: order, tender_name: "Gift Card", amount: 500, status: "pending")
      end

      it ".successful returns paid payments" do
        expect(payment_class.successful.count).to eq(1)
      end

      it ".cash returns cash payments" do
        expect(payment_class.cash.count).to eq(1)
      end

      it ".by_tender filters by tender name" do
        expect(payment_class.by_tender("Gift Card").count).to eq(1)
      end
    end
  end

  # ---------- ApiRequest ----------
  describe CloverSandboxSimulator::Models::ApiRequest do
    it "validates required fields" do
      req = api_class.new
      expect(req).not_to be_valid
      expect(req.errors[:http_method]).to include("can't be blank")
      expect(req.errors[:url]).to include("can't be blank")
    end

    describe "scopes" do
      before do
        api_class.create!(http_method: "GET", url: "https://sandbox.dev.clover.com/v3/merchants/M1/orders", response_status: 200, resource_type: "Order")
        api_class.create!(http_method: "POST", url: "https://sandbox.dev.clover.com/v3/merchants/M1/orders", response_status: 500, error_message: "Server Error", resource_type: "Order")
        api_class.create!(http_method: "GET", url: "https://sandbox.dev.clover.com/v3/merchants/M2/items", response_status: 200, resource_type: "Item")
      end

      it ".errors returns failed requests" do
        expect(api_class.errors.count).to eq(1)
      end

      it ".successful returns OK requests" do
        expect(api_class.successful.count).to eq(2)
      end

      it ".for_resource filters by type" do
        expect(api_class.for_resource("Order").count).to eq(2)
      end

      it ".for_merchant filters by merchant ID in URL" do
        expect(api_class.for_merchant("M1").count).to eq(2)
        expect(api_class.for_merchant("M2").count).to eq(1)
      end

      it ".gets returns GET requests" do
        expect(api_class.gets.count).to eq(2)
      end

      it ".posts returns POST requests" do
        expect(api_class.posts.count).to eq(1)
      end
    end

    it "#error? detects errors" do
      ok = api_class.new(response_status: 200)
      expect(ok.error?).to be false

      err = api_class.new(response_status: 500)
      expect(err.error?).to be true

      msg = api_class.new(error_message: "timeout")
      expect(msg.error?).to be true
    end
  end

  # ---------- DailySummary ----------
  describe CloverSandboxSimulator::Models::DailySummary do
    it "validates uniqueness of merchant_id + business_date" do
      summary_class.create!(merchant_id: "M1", business_date: Date.today)
      dup = summary_class.new(merchant_id: "M1", business_date: Date.today)
      expect(dup).not_to be_valid
    end

    it "allows same date for different merchants" do
      summary_class.create!(merchant_id: "M1", business_date: Date.today)
      expect(summary_class.new(merchant_id: "M2", business_date: Date.today)).to be_valid
    end

    describe ".generate_for!" do
      before do
        order_class.create!(clover_merchant_id: "M1", business_date: Date.today, status: "paid",
                            total: 2500, tax_amount: 200, tip_amount: 300, discount_amount: 100, meal_period: "lunch", dining_option: "HERE")
        order_class.create!(clover_merchant_id: "M1", business_date: Date.today, status: "paid",
                            total: 1500, tax_amount: 100, tip_amount: 200, discount_amount: 0, meal_period: "dinner", dining_option: "TO_GO")
        order_class.create!(clover_merchant_id: "M1", business_date: Date.today, status: "refunded",
                            total: 500)

        paid_orders = order_class.where(status: "paid")
        paid_orders.each do |o|
          payment_class.create!(simulated_order: o, tender_name: "Cash", amount: o.total, status: "paid")
        end
      end

      it "creates a summary with correct aggregations" do
        summary = summary_class.generate_for!("M1", Date.today)

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
        summary = summary_class.generate_for!("M1", Date.today)

        expect(summary.breakdown["by_meal_period"]).to include("lunch" => 1, "dinner" => 1)
        expect(summary.breakdown["by_dining_option"]).to include("HERE" => 1, "TO_GO" => 1)
      end

      it "updates existing summary (idempotent)" do
        summary_class.generate_for!("M1", Date.today)
        expect { summary_class.generate_for!("M1", Date.today) }.not_to change { summary_class.count }
      end
    end

    it "#total_revenue_dollars converts cents" do
      s = summary_class.new(total_revenue: 12345)
      expect(s.total_revenue_dollars).to eq(123.45)
    end
  end

  # ---------- Inheritance ----------
  describe CloverSandboxSimulator::Models::Record do
    it "is abstract" do
      expect(described_class.abstract_class?).to be true
    end

    it "is the parent of all models" do
      [bt_class, cat_class, item_class, order_class, payment_class, api_class, summary_class].each do |klass|
        expect(klass.superclass).to eq(described_class)
      end
    end
  end
end
