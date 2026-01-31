# frozen_string_literal: true

require "spec_helper"

RSpec.describe CloverSandboxSimulator::Services::Clover::PaymentService do
  before { stub_clover_credentials }

  let(:service) { described_class.new }
  let(:base_url) { "https://sandbox.dev.clover.com/v3/merchants/TEST_MERCHANT_ID" }

  describe "#process_payment" do
    it "creates a payment for an order" do
      stub_request(:post, "#{base_url}/orders/ORDER123/payments")
        .with(body: hash_including(
          "order" => { "id" => "ORDER123" },
          "tender" => { "id" => "TENDER1" },
          "amount" => 1500,
          "tipAmount" => 300,
          "taxAmount" => 124
        ))
        .to_return(
          status: 200,
          body: { id: "PAY123", amount: 1500, tipAmount: 300, taxAmount: 124 }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      payment = service.process_payment(
        order_id: "ORDER123",
        amount: 1500,
        tender_id: "TENDER1",
        employee_id: "EMP1",
        tip_amount: 300,
        tax_amount: 124
      )

      expect(payment["id"]).to eq("PAY123")
      expect(payment["amount"]).to eq(1500)
    end
  end

  describe "#process_split_payment" do
    it "creates multiple payments for split payment" do
      stub_request(:post, "#{base_url}/orders/ORDER123/payments")
        .to_return(
          status: 200,
          body: ->(request) {
            data = JSON.parse(request.body)
            { id: "PAY_#{rand(1000)}", amount: data["amount"] }.to_json
          },
          headers: { "Content-Type" => "application/json" }
        )

      splits = [
        { tender: { "id" => "T1" }, percentage: 60 },
        { tender: { "id" => "T2" }, percentage: 40 }
      ]

      payments = service.process_split_payment(
        order_id: "ORDER123",
        total_amount: 10000,
        tip_amount: 1500,
        tax_amount: 825,
        employee_id: "EMP1",
        splits: splits
      )

      expect(payments.size).to eq(2)
    end
  end

  describe "#generate_tip" do
    it "generates tip between 15-25% of subtotal" do
      100.times do
        tip = service.generate_tip(10000) # $100 subtotal

        expect(tip).to be >= 1500 # 15% min
        expect(tip).to be <= 2500 # 25% max
      end
    end
  end
end
