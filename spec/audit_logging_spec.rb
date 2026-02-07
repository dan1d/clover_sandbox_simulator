# frozen_string_literal: true

require "spec_helper"

# ── BaseService API request audit logging ──────────────────────

RSpec.describe CloverSandboxSimulator::Services::BaseService, :db do
  let(:config) { CloverSandboxSimulator.configuration }
  let(:api_request_model) { CloverSandboxSimulator::Models::ApiRequest }

  # Subclass BaseService to expose the protected `request` method for testing
  let(:test_service_class) do
    Class.new(described_class) do
      public :request, :endpoint
    end
  end
  let(:service) { test_service_class.new }

  # VCR blocks all HTTP when no cassette is inserted; turn it off for
  # these unit tests which use plain WebMock stubs.
  around do |example|
    VCR.turned_off { example.run }
  end

  describe "#request audit logging" do
    context "on successful request" do
      before do
        stub_request(:get, /.*\/v3\/merchants\/.*/)
          .to_return(status: 200, body: '{"elements":[]}', headers: { "Content-Type" => "application/json" })
      end

      it "creates an ApiRequest record" do
        expect {
          service.request(:get, service.endpoint("items"))
        }.to change { api_request_model.count }.by(1)
      end

      it "records http_method, url, response_status, and duration_ms" do
        service.request(:get, service.endpoint("items"))

        record = api_request_model.last
        expect(record.http_method).to eq("GET")
        expect(record.url).to include("v3/merchants/")
        expect(record.url).to include("/items")
        expect(record.response_status).to eq(200)
        expect(record.duration_ms).to be_a(Integer)
        expect(record.duration_ms).to be >= 0
        expect(record.error_message).to be_nil
      end

      it "records response_payload" do
        service.request(:get, service.endpoint("items"))

        record = api_request_model.last
        expect(record.response_payload).to eq("elements" => [])
      end

      it "records resource_type and resource_id when provided" do
        service.request(:get, service.endpoint("items"),
                         resource_type: "Item", resource_id: "ITEM123")

        record = api_request_model.last
        expect(record.resource_type).to eq("Item")
        expect(record.resource_id).to eq("ITEM123")
      end
    end

    context "on POST request with payload" do
      before do
        stub_request(:post, /.*\/v3\/merchants\/.*/)
          .to_return(status: 201, body: '{"id":"ORDER1"}', headers: { "Content-Type" => "application/json" })
      end

      it "records request_payload" do
        payload = { name: "Test Order", total: 1500 }
        service.request(:post, service.endpoint("orders"), payload: payload)

        record = api_request_model.last
        expect(record.http_method).to eq("POST")
        expect(record.request_payload).to eq("name" => "Test Order", "total" => 1500)
        expect(record.response_status).to eq(201)
      end
    end

    context "on PUT request" do
      before do
        stub_request(:put, /.*\/v3\/merchants\/.*/)
          .to_return(status: 200, body: '{"state":"paid"}', headers: { "Content-Type" => "application/json" })
      end

      it "records PUT method" do
        service.request(:put, service.endpoint("orders/ORDER1"),
                         payload: { state: "paid" }, resource_type: "Order", resource_id: "ORDER1")

        record = api_request_model.last
        expect(record.http_method).to eq("PUT")
        expect(record.resource_type).to eq("Order")
        expect(record.resource_id).to eq("ORDER1")
      end
    end

    context "on DELETE request" do
      before do
        stub_request(:delete, /.*\/v3\/merchants\/.*/)
          .to_return(status: 200, body: "", headers: { "Content-Type" => "application/json" })
      end

      it "records DELETE method" do
        service.request(:delete, service.endpoint("items/ITEM1"),
                         resource_type: "Item", resource_id: "ITEM1")

        record = api_request_model.last
        expect(record.http_method).to eq("DELETE")
      end
    end

    context "on server error (500)" do
      before do
        stub_request(:post, /.*\/v3\/merchants\/.*/)
          .to_return(status: 500, body: '{"message":"Internal Server Error"}',
                     headers: { "Content-Type" => "application/json" })
      end

      it "records the 500 status and error_message" do
        begin
          service.request(:post, service.endpoint("orders"), payload: { test: true })
        rescue CloverSandboxSimulator::ApiError
          # expected
        end

        record = api_request_model.last
        expect(record.http_method).to eq("POST")
        expect(record.response_status).to eq(500)
        expect(record.error_message).to include("500")
        expect(record.request_payload).to eq("test" => true)
      end
    end

    context "on API error (RestClient::ExceptionWithResponse)" do
      before do
        stub_request(:get, /.*\/v3\/merchants\/.*/)
          .to_return(status: 404, body: '{"message":"Not found"}', headers: { "Content-Type" => "application/json" })
      end

      it "creates an ApiRequest record with error_message" do
        expect {
          begin
            service.request(:get, service.endpoint("items"))
          rescue CloverSandboxSimulator::ApiError
            # expected
          end
        }.to change { api_request_model.count }.by(1)

        record = api_request_model.last
        expect(record.http_method).to eq("GET")
        expect(record.response_status).to eq(404)
        expect(record.error_message).to include("404")
      end

      it "still raises the ApiError" do
        expect {
          service.request(:get, service.endpoint("items"))
        }.to raise_error(CloverSandboxSimulator::ApiError)
      end
    end

    context "on transport-layer error (network failure)" do
      before do
        stub_request(:get, /.*\/v3\/merchants\/.*/)
          .to_raise(SocketError.new("getaddrinfo: Name or service not known"))
      end

      it "creates an ApiRequest record with error_message and nil response_status" do
        expect {
          begin
            service.request(:get, service.endpoint("items"))
          rescue CloverSandboxSimulator::ApiError
            # expected
          end
        }.to change { api_request_model.count }.by(1)

        record = api_request_model.last
        expect(record.http_method).to eq("GET")
        expect(record.error_message).to include("Name or service not known")
        expect(record.response_status).to be_nil
      end
    end

    context "when database is not connected" do
      before do
        allow(CloverSandboxSimulator::Database).to receive(:connected?).and_return(false)

        stub_request(:get, /.*\/v3\/merchants\/.*/)
          .to_return(status: 200, body: '{"elements":[]}', headers: { "Content-Type" => "application/json" })
      end

      it "does not create an ApiRequest record" do
        expect {
          service.request(:get, service.endpoint("items"))
        }.not_to change { api_request_model.count }
      end

      it "still returns the parsed response" do
        result = service.request(:get, service.endpoint("items"))
        expect(result).to eq("elements" => [])
      end
    end
  end
end

# ── OrderGenerator order/payment tracking ──────────────────────

RSpec.describe CloverSandboxSimulator::Generators::OrderGenerator, :db do
  let(:order_model) { CloverSandboxSimulator::Models::SimulatedOrder }
  let(:payment_model) { CloverSandboxSimulator::Models::SimulatedPayment }
  let(:summary_model) { CloverSandboxSimulator::Models::DailySummary }
  let(:merchant_id) { CloverSandboxSimulator.configuration.merchant_id }

  let(:generator) { described_class.new(refund_percentage: 0) }

  describe "#track_simulated_order (private)" do
    let(:clover_order) do
      {
        "id" => "CLOVER_ORDER_123",
        "state" => "paid",
        "total" => 2500,
        "lineItems" => { "elements" => [{ "id" => "LI1" }, { "id" => "LI2" }] },
        "payments" => {
          "elements" => [
            {
              "id" => "PAY_1",
              "amount" => 2500,
              "tipAmount" => 400,
              "taxAmount" => 200,
              "result" => "SUCCESS",
              "tender" => { "label" => "Credit Card" }
            }
          ]
        },
        "discounts" => { "elements" => [] },
        "_metadata" => {
          party_size: 3,
          order_type: "Dine In",
          discount_applied: nil,
          modifier_count: 1,
          tip: 400,
          tax: 200
        }
      }
    end

    it "creates a SimulatedOrder record" do
      expect {
        generator.send(:track_simulated_order, clover_order,
                        period: :dinner, dining: "HERE", date: Date.today)
      }.to change { order_model.count }.by(1)

      sim = order_model.last
      expect(sim.clover_order_id).to eq("CLOVER_ORDER_123")
      expect(sim.clover_merchant_id).to eq(merchant_id)
      expect(sim.status).to eq("paid")
      expect(sim.subtotal).to eq(2500)
      expect(sim.tax_amount).to eq(200)
      expect(sim.tip_amount).to eq(400)
      expect(sim.total).to eq(2500 + 200 + 400)
      expect(sim.dining_option).to eq("HERE")
      expect(sim.meal_period).to eq("dinner")
      expect(sim.business_date).to eq(Date.today)
      expect(sim.metadata["party_size"]).to eq(3)
      expect(sim.metadata["line_item_count"]).to eq(2)
    end

    it "creates SimulatedPayment children" do
      expect {
        generator.send(:track_simulated_order, clover_order,
                        period: :dinner, dining: "HERE", date: Date.today)
      }.to change { payment_model.count }.by(1)

      pay = payment_model.last
      expect(pay.clover_payment_id).to eq("PAY_1")
      expect(pay.tender_name).to eq("Credit Card")
      expect(pay.amount).to eq(2500)
      expect(pay.tip_amount).to eq(400)
      expect(pay.tax_amount).to eq(200)
      expect(pay.status).to eq("SUCCESS")
      expect(pay.payment_type).to eq("card")
    end

    it "identifies cash payment type" do
      clover_order["payments"]["elements"][0]["tender"]["label"] = "Cash"
      generator.send(:track_simulated_order, clover_order,
                      period: :lunch, dining: "TO_GO", date: Date.today)

      expect(payment_model.last.payment_type).to eq("cash")
    end

    it "handles orders with multiple payments" do
      clover_order["payments"]["elements"] << {
        "id" => "PAY_2",
        "amount" => 1000,
        "tipAmount" => 100,
        "taxAmount" => 50,
        "result" => "SUCCESS",
        "tender" => { "label" => "Cash" }
      }

      expect {
        generator.send(:track_simulated_order, clover_order,
                        period: :dinner, dining: "HERE", date: Date.today)
      }.to change { payment_model.count }.by(2)
    end

    it "handles orders with no payments gracefully" do
      clover_order["payments"] = nil

      expect {
        generator.send(:track_simulated_order, clover_order,
                        period: :dinner, dining: "HERE", date: Date.today)
      }.to change { order_model.count }.by(1)

      expect(payment_model.count).to eq(0)
    end

    it "creates correct records for split payments (2-way)" do
      clover_order["payments"]["elements"] = [
        {
          "id" => "SPLIT_1",
          "amount" => 1250,
          "tipAmount" => 200,
          "taxAmount" => 100,
          "result" => "SUCCESS",
          "tender" => { "label" => "Credit Card" }
        },
        {
          "id" => "SPLIT_2",
          "amount" => 1250,
          "tipAmount" => 200,
          "taxAmount" => 100,
          "result" => "SUCCESS",
          "tender" => { "label" => "Cash" }
        }
      ]

      generator.send(:track_simulated_order, clover_order,
                      period: :dinner, dining: "HERE", date: Date.today)

      expect(payment_model.count).to eq(2)

      card_pay = payment_model.find_by(clover_payment_id: "SPLIT_1")
      cash_pay = payment_model.find_by(clover_payment_id: "SPLIT_2")

      expect(card_pay.payment_type).to eq("card")
      expect(card_pay.amount).to eq(1250)
      expect(cash_pay.payment_type).to eq("cash")
      expect(cash_pay.amount).to eq(1250)

      # Both belong to the same SimulatedOrder
      sim_order = order_model.last
      expect(card_pay.simulated_order_id).to eq(sim_order.id)
      expect(cash_pay.simulated_order_id).to eq(sim_order.id)
    end

    it "records discount metadata when a discount is applied" do
      clover_order["_metadata"][:discount_applied] = { type: :loyalty, name: "10% Loyalty" }
      clover_order["discounts"] = { "elements" => [{ "amount" => 250 }] }

      generator.send(:track_simulated_order, clover_order,
                      period: :lunch, dining: "HERE", date: Date.today)

      sim = order_model.last
      expect(sim.discount_amount).to eq(250)
      expect(sim.metadata["discount_type"]).to eq("loyalty")
    end

    it "records order_type in metadata" do
      clover_order["_metadata"][:order_type] = "Delivery"

      generator.send(:track_simulated_order, clover_order,
                      period: :dinner, dining: "DELIVERY", date: Date.today)

      sim = order_model.last
      expect(sim.metadata["order_type"]).to eq("Delivery")
    end

    context "when database is not connected" do
      before do
        allow(CloverSandboxSimulator::Database).to receive(:connected?).and_return(false)
      end

      it "does not create any records" do
        expect {
          generator.send(:track_simulated_order, clover_order,
                          period: :dinner, dining: "HERE", date: Date.today)
        }.not_to change { order_model.count }
      end
    end
  end

  describe "#track_refund (private)" do
    it "updates the SimulatedOrder status to refunded" do
      sim = order_model.create!(
        clover_order_id: "ORDER_REF_1",
        clover_merchant_id: merchant_id,
        status: "paid",
        business_date: Date.today
      )

      generator.send(:track_refund, "ORDER_REF_1")
      expect(sim.reload.status).to eq("refunded")
    end

    it "no-ops for unknown order IDs" do
      expect {
        generator.send(:track_refund, "NONEXISTENT_ORDER")
      }.not_to raise_error
    end

    context "when database is not connected" do
      before do
        allow(CloverSandboxSimulator::Database).to receive(:connected?).and_return(false)
      end

      it "does not attempt updates" do
        expect(order_model).not_to receive(:find_by)
        generator.send(:track_refund, "ORDER_REF_1")
      end
    end
  end

  describe "#generate_daily_summary (private)" do
    before do
      # Create 2 paid orders (using instance variables for before block)
      # rubocop:disable RSpec/InstanceVariable
      @order1 = order_model.create!(
        clover_order_id: "SUM_ORDER_1",
        clover_merchant_id: merchant_id,
        status: "paid",
        subtotal: 3000,
        total: 3500,
        tax_amount: 300,
        tip_amount: 200,
        discount_amount: 100,
        business_date: Date.today,
        meal_period: "lunch",
        dining_option: "HERE"
      )

      @order2 = order_model.create!(
        clover_order_id: "SUM_ORDER_2",
        clover_merchant_id: merchant_id,
        status: "paid",
        subtotal: 2000,
        total: 2400,
        tax_amount: 200,
        tip_amount: 150,
        discount_amount: 0,
        business_date: Date.today,
        meal_period: "dinner",
        dining_option: "TO_GO"
      )

      # Create a refunded order
      @refunded = order_model.create!(
        clover_order_id: "SUM_ORDER_3",
        clover_merchant_id: merchant_id,
        status: "refunded",
        subtotal: 1500,
        total: 1800,
        tax_amount: 150,
        tip_amount: 100,
        business_date: Date.today,
        meal_period: "dinner",
        dining_option: "HERE"
      )

      # Create payments for orders
      payment_model.create!(
        simulated_order: @order1,
        clover_payment_id: "SUMPAY_1",
        tender_name: "Credit Card",
        amount: 3500,
        tip_amount: 200,
        tax_amount: 300,
        status: "SUCCESS",
        payment_type: "card"
      )

      payment_model.create!(
        simulated_order: @order2,
        clover_payment_id: "SUMPAY_2",
        tender_name: "Cash",
        amount: 2400,
        tip_amount: 150,
        tax_amount: 200,
        status: "SUCCESS",
        payment_type: "cash"
      )
    end

    it "creates a DailySummary with correct aggregated counts" do
      expect {
        generator.send(:generate_daily_summary, Date.today)
      }.to change { summary_model.count }.by(1)

      summary = summary_model.last
      expect(summary.merchant_id).to eq(merchant_id)
      expect(summary.business_date).to eq(Date.today)
      expect(summary.order_count).to eq(2)      # only paid orders
      expect(summary.payment_count).to eq(2)
      expect(summary.refund_count).to eq(1)
    end

    it "aggregates revenue, tax, tips, and discounts" do
      generator.send(:generate_daily_summary, Date.today)

      summary = summary_model.last
      expect(summary.total_revenue).to eq(3500 + 2400)   # sum of paid order totals
      expect(summary.total_tax).to eq(300 + 200)
      expect(summary.total_tips).to eq(200 + 150)
      expect(summary.total_discounts).to eq(100 + 0)
    end

    it "builds breakdown by meal_period and dining_option" do
      generator.send(:generate_daily_summary, Date.today)

      summary = summary_model.last
      breakdown = summary.breakdown

      expect(breakdown["by_meal_period"]).to include("lunch" => 1, "dinner" => 1)
      expect(breakdown["by_dining_option"]).to include("HERE" => 1, "TO_GO" => 1)
      expect(breakdown["by_tender"]).to include("Credit Card" => 1, "Cash" => 1)
      expect(breakdown["revenue_by_meal_period"]["lunch"]).to eq(3500)
      expect(breakdown["revenue_by_meal_period"]["dinner"]).to eq(2400)
    end

    it "is idempotent — updates existing summary" do
      generator.send(:generate_daily_summary, Date.today)
      expect {
        generator.send(:generate_daily_summary, Date.today)
      }.not_to change { summary_model.count }
    end

    it "updates summary when new orders appear" do
      generator.send(:generate_daily_summary, Date.today)
      summary = summary_model.last
      expect(summary.order_count).to eq(2)

      # Add another paid order
      order_model.create!(
        clover_order_id: "SUM_ORDER_4",
        clover_merchant_id: merchant_id,
        status: "paid",
        total: 1000,
        business_date: Date.today,
        meal_period: "breakfast",
        dining_option: "HERE"
      )

      generator.send(:generate_daily_summary, Date.today)
      expect(summary.reload.order_count).to eq(3)
    end

    context "when database is not connected" do
      before do
        allow(CloverSandboxSimulator::Database).to receive(:connected?).and_return(false)
      end

      it "does not create a DailySummary" do
        expect {
          generator.send(:generate_daily_summary, Date.today)
        }.not_to change { summary_model.count }
      end
    end
  end

  # ── Status transition tracking ─────────────────────────────────

  describe "order status transitions" do
    it "tracks open -> paid -> refunded lifecycle" do
      # 1. Order created (tracked as paid)
      order = order_model.create!(
        clover_order_id: "LIFECYCLE_1",
        clover_merchant_id: merchant_id,
        status: "paid",
        business_date: Date.today
      )
      expect(order.status).to eq("paid")

      # 2. Refund processed
      generator.send(:track_refund, "LIFECYCLE_1")
      expect(order.reload.status).to eq("refunded")

      # Verify scopes reflect the transition
      expect(order_model.successful.count).to eq(0)
      expect(order_model.refunded.count).to eq(1)
    end
  end
end
