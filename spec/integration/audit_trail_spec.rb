# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Audit trail end-to-end", :db, :integration do
  let(:order_model) { CloverSandboxSimulator::Models::SimulatedOrder }
  let(:payment_model) { CloverSandboxSimulator::Models::SimulatedPayment }
  let(:api_model) { CloverSandboxSimulator::Models::ApiRequest }
  let(:summary_model) { CloverSandboxSimulator::Models::DailySummary }
  let(:merchant_id) { CloverSandboxSimulator.configuration.merchant_id }

  # VCR blocks all HTTP when no cassette is inserted; turn it off
  # so we can use plain WebMock stubs.
  around do |example|
    VCR.turned_off { example.run }
  end

  # ── Helpers ────────────────────────────────────────────────────

  let(:test_service_class) do
    Class.new(CloverSandboxSimulator::Services::BaseService) do
      public :request, :endpoint
    end
  end
  let(:service) { test_service_class.new }

  let(:generator) { CloverSandboxSimulator::Generators::OrderGenerator.new(refund_percentage: 0) }

  def build_clover_order(id:, total:, tax:, tip:, payments: [], dining: "HERE", period: :dinner)
    {
      "id" => id,
      "state" => "paid",
      "total" => total,
      "lineItems" => { "elements" => [{ "id" => "LI_#{id}" }] },
      "payments" => { "elements" => payments },
      "discounts" => { "elements" => [] },
      "_metadata" => {
        party_size: 2,
        order_type: "Dine In",
        discount_applied: nil,
        modifier_count: 0,
        tip: tip,
        tax: tax
      }
    }
  end

  def build_payment(id:, amount:, tip: 0, tax: 0, tender: "Credit Card")
    {
      "id" => id,
      "amount" => amount,
      "tipAmount" => tip,
      "taxAmount" => tax,
      "result" => "SUCCESS",
      "tender" => { "label" => tender }
    }
  end

  # ── API request audit trail ────────────────────────────────────

  describe "ApiRequest records capture all HTTP calls" do
    before do
      stub_request(:get, /.*\/v3\/merchants\/.*\/items/)
        .to_return(status: 200, body: '{"elements":[]}', headers: { "Content-Type" => "application/json" })
      stub_request(:post, /.*\/v3\/merchants\/.*\/orders/)
        .to_return(status: 201, body: '{"id":"ORD1"}', headers: { "Content-Type" => "application/json" })
      stub_request(:put, /.*\/v3\/merchants\/.*\/orders/)
        .to_return(status: 200, body: '{"state":"paid"}', headers: { "Content-Type" => "application/json" })
      stub_request(:get, /.*\/v3\/merchants\/.*\/employees/)
        .to_return(status: 404, body: '{"message":"Not found"}', headers: { "Content-Type" => "application/json" })
    end

    it "records GET, POST, and PUT requests with correct metadata" do
      # GET items
      service.request(:get, service.endpoint("items"), resource_type: "Item")
      # POST order
      service.request(:post, service.endpoint("orders"), payload: { total: 2500 }, resource_type: "Order")
      # PUT order
      service.request(:put, service.endpoint("orders/ORD1"), payload: { state: "paid" }, resource_type: "Order", resource_id: "ORD1")

      expect(api_model.count).to eq(3)

      get_req = api_model.find_by(http_method: "GET")
      expect(get_req.response_status).to eq(200)
      expect(get_req.resource_type).to eq("Item")
      expect(get_req.duration_ms).to be >= 0

      post_req = api_model.find_by(http_method: "POST")
      expect(post_req.response_status).to eq(201)
      expect(post_req.request_payload).to eq("total" => 2500)

      put_req = api_model.find_by(http_method: "PUT")
      expect(put_req.resource_id).to eq("ORD1")
    end

    it "captures error responses with error_message" do
      begin
        service.request(:get, service.endpoint("employees"))
      rescue CloverSandboxSimulator::ApiError
        # expected
      end

      error_req = api_model.last
      expect(error_req.response_status).to eq(404)
      expect(error_req.error_message).to include("404")
      expect(error_req.http_method).to eq("GET")
    end

    it "tracks request count using scopes" do
      service.request(:get, service.endpoint("items"))
      service.request(:post, service.endpoint("orders"), payload: {})
      service.request(:get, service.endpoint("items"))

      expect(api_model.gets.count).to eq(2)
      expect(api_model.posts.count).to eq(1)
      expect(api_model.successful.count).to eq(3)
      expect(api_model.errors.count).to eq(0)
    end
  end

  # ── SimulatedOrder/Payment creation ────────────────────────────

  describe "SimulatedOrder and SimulatedPayment records" do
    it "creates order with single payment" do
      payment = build_payment(id: "PAY_S1", amount: 3000, tip: 400, tax: 250, tender: "Credit Card")
      order = build_clover_order(
        id: "ORD_S1", total: 3000, tax: 250, tip: 400,
        payments: [payment]
      )

      generator.send(:track_simulated_order, order, period: :dinner, dining: "HERE", date: Date.today)

      sim_order = order_model.last
      expect(sim_order.clover_order_id).to eq("ORD_S1")
      expect(sim_order.status).to eq("paid")
      expect(sim_order.subtotal).to eq(3000)
      expect(sim_order.tax_amount).to eq(250)
      expect(sim_order.tip_amount).to eq(400)
      expect(sim_order.total).to eq(3000 + 250 + 400)
      expect(sim_order.dining_option).to eq("HERE")
      expect(sim_order.meal_period).to eq("dinner")

      sim_payment = payment_model.last
      expect(sim_payment.clover_payment_id).to eq("PAY_S1")
      expect(sim_payment.amount).to eq(3000)
      expect(sim_payment.tender_name).to eq("Credit Card")
      expect(sim_payment.payment_type).to eq("card")
      expect(sim_payment.simulated_order_id).to eq(sim_order.id)
    end

    it "creates order with split payments (card + cash)" do
      payments = [
        build_payment(id: "SPLIT_A", amount: 1500, tip: 200, tax: 125, tender: "Credit Card"),
        build_payment(id: "SPLIT_B", amount: 1500, tip: 200, tax: 125, tender: "Cash")
      ]
      order = build_clover_order(
        id: "ORD_SPLIT", total: 3000, tax: 250, tip: 400,
        payments: payments
      )

      generator.send(:track_simulated_order, order, period: :lunch, dining: "HERE", date: Date.today)

      expect(order_model.count).to eq(1)
      expect(payment_model.count).to eq(2)

      card_pay = payment_model.find_by(clover_payment_id: "SPLIT_A")
      cash_pay = payment_model.find_by(clover_payment_id: "SPLIT_B")

      expect(card_pay.payment_type).to eq("card")
      expect(cash_pay.payment_type).to eq("cash")
      expect(card_pay.amount + cash_pay.amount).to eq(3000)
    end

    it "tracks refund status transition" do
      payment = build_payment(id: "PAY_REF", amount: 2000, tender: "Credit Card")
      order = build_clover_order(id: "ORD_REF", total: 2000, tax: 150, tip: 300, payments: [payment])

      generator.send(:track_simulated_order, order, period: :dinner, dining: "HERE", date: Date.today)
      expect(order_model.last.status).to eq("paid")

      generator.send(:track_refund, "ORD_REF")
      expect(order_model.last.status).to eq("refunded")
    end

    it "records orders across two different meal periods" do
      pay1 = build_payment(id: "PAY_L", amount: 1500, tender: "Cash")
      order1 = build_clover_order(id: "ORD_L", total: 1500, tax: 100, tip: 200, payments: [pay1])
      generator.send(:track_simulated_order, order1, period: :lunch, dining: "TO_GO", date: Date.today)

      pay2 = build_payment(id: "PAY_D", amount: 4000, tender: "Credit Card")
      order2 = build_clover_order(id: "ORD_D", total: 4000, tax: 300, tip: 600, payments: [pay2])
      generator.send(:track_simulated_order, order2, period: :dinner, dining: "HERE", date: Date.today)

      expect(order_model.for_meal_period("lunch").count).to eq(1)
      expect(order_model.for_meal_period("dinner").count).to eq(1)
      expect(order_model.for_dining_option("TO_GO").count).to eq(1)
      expect(order_model.for_dining_option("HERE").count).to eq(1)
    end
  end

  # ── DailySummary aggregation ───────────────────────────────────

  describe "DailySummary aggregation matches individual records" do
    before do
      # Create 3 paid orders with different periods/dining/tenders
      [
        { id: "AGG_1", total: 3000, tax: 250, tip: 400, discount: 100,
          period: :lunch, dining: "HERE", pay_id: "PAY_A1", tender: "Credit Card" },
        { id: "AGG_2", total: 4500, tax: 350, tip: 600, discount: 0,
          period: :dinner, dining: "HERE", pay_id: "PAY_A2", tender: "Credit Card" },
        { id: "AGG_3", total: 1500, tax: 100, tip: 150, discount: 50,
          period: :lunch, dining: "TO_GO", pay_id: "PAY_A3", tender: "Cash" }
      ].each do |data|
        order_model.create!(
          clover_order_id: data[:id],
          clover_merchant_id: merchant_id,
          status: "paid",
          subtotal: data[:total],
          total: data[:total],
          tax_amount: data[:tax],
          tip_amount: data[:tip],
          discount_amount: data[:discount],
          business_date: Date.today,
          meal_period: data[:period].to_s,
          dining_option: data[:dining]
        )

        payment_model.create!(
          simulated_order: order_model.last,
          clover_payment_id: data[:pay_id],
          tender_name: data[:tender],
          amount: data[:total],
          tip_amount: data[:tip],
          tax_amount: data[:tax],
          status: "SUCCESS",
          payment_type: data[:tender] == "Cash" ? "cash" : "card"
        )
      end

      # Create 1 refunded order
      order_model.create!(
        clover_order_id: "AGG_REF",
        clover_merchant_id: merchant_id,
        status: "refunded",
        total: 2000,
        business_date: Date.today,
        meal_period: "dinner",
        dining_option: "HERE"
      )
    end

    it "generates correct aggregate counts" do
      generator.send(:generate_daily_summary, Date.today)

      summary = summary_model.last
      expect(summary.order_count).to eq(3)          # 3 paid orders
      expect(summary.payment_count).to eq(3)
      expect(summary.refund_count).to eq(1)          # 1 refunded
    end

    it "aggregates revenue matching sum of paid order totals" do
      generator.send(:generate_daily_summary, Date.today)

      summary = summary_model.last
      expected_revenue = 3000 + 4500 + 1500
      expect(summary.total_revenue).to eq(expected_revenue)
    end

    it "aggregates tax matching sum of paid orders" do
      generator.send(:generate_daily_summary, Date.today)

      summary = summary_model.last
      expected_tax = 250 + 350 + 100
      expect(summary.total_tax).to eq(expected_tax)
    end

    it "aggregates tips matching sum of paid orders" do
      generator.send(:generate_daily_summary, Date.today)

      summary = summary_model.last
      expected_tips = 400 + 600 + 150
      expect(summary.total_tips).to eq(expected_tips)
    end

    it "aggregates discounts matching sum of paid orders" do
      generator.send(:generate_daily_summary, Date.today)

      summary = summary_model.last
      expected_discounts = 100 + 0 + 50
      expect(summary.total_discounts).to eq(expected_discounts)
    end

    it "breakdown by_meal_period matches individual order counts" do
      generator.send(:generate_daily_summary, Date.today)

      breakdown = summary_model.last.breakdown
      expect(breakdown["by_meal_period"]["lunch"]).to eq(2)
      expect(breakdown["by_meal_period"]["dinner"]).to eq(1)
    end

    it "breakdown by_dining_option matches individual order counts" do
      generator.send(:generate_daily_summary, Date.today)

      breakdown = summary_model.last.breakdown
      expect(breakdown["by_dining_option"]["HERE"]).to eq(2)
      expect(breakdown["by_dining_option"]["TO_GO"]).to eq(1)
    end

    it "breakdown by_tender matches individual payment counts" do
      generator.send(:generate_daily_summary, Date.today)

      breakdown = summary_model.last.breakdown
      expect(breakdown["by_tender"]["Credit Card"]).to eq(2)
      expect(breakdown["by_tender"]["Cash"]).to eq(1)
    end

    it "revenue_by_meal_period matches sum of paid order totals per period" do
      generator.send(:generate_daily_summary, Date.today)

      breakdown = summary_model.last.breakdown
      expect(breakdown["revenue_by_meal_period"]["lunch"]).to eq(3000 + 1500)
      expect(breakdown["revenue_by_meal_period"]["dinner"]).to eq(4500)
    end

    it "revenue_by_dining_option matches sum of paid order totals per option" do
      generator.send(:generate_daily_summary, Date.today)

      breakdown = summary_model.last.breakdown
      expect(breakdown["revenue_by_dining_option"]["HERE"]).to eq(3000 + 4500)
      expect(breakdown["revenue_by_dining_option"]["TO_GO"]).to eq(1500)
    end

    it "is idempotent — re-running produces same result" do
      generator.send(:generate_daily_summary, Date.today)
      first_summary = summary_model.last.attributes

      generator.send(:generate_daily_summary, Date.today)
      second_summary = summary_model.last.attributes

      # Same record, same values (except updated_at)
      expect(summary_model.count).to eq(1)
      %w[order_count payment_count refund_count total_revenue total_tax total_tips total_discounts].each do |attr|
        expect(second_summary[attr]).to eq(first_summary[attr]),
          "#{attr} changed: #{first_summary[attr]} -> #{second_summary[attr]}"
      end
    end
  end
end
