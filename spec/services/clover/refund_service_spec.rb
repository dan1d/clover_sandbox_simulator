# frozen_string_literal: true

require "spec_helper"

RSpec.describe CloverSandboxSimulator::Services::Clover::RefundService do
  before { stub_clover_credentials }

  let(:service) { described_class.new }
  let(:base_url) { "https://sandbox.dev.clover.com/v3/merchants/TEST_MERCHANT_ID" }

  describe "#fetch_refunds" do
    it "returns all refunds" do
      stub_request(:get, "#{base_url}/refunds")
        .to_return(
          status: 200,
          body: {
            elements: [
              { id: "REF1", amount: 1500, payment: { id: "PAY1" } },
              { id: "REF2", amount: 2500, payment: { id: "PAY2" } }
            ]
          }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      refunds = service.fetch_refunds

      expect(refunds.size).to eq(2)
      expect(refunds.first["id"]).to eq("REF1")
    end

    it "supports pagination with limit and offset" do
      stub_request(:get, "#{base_url}/refunds")
        .with(query: { limit: 10, offset: 5 })
        .to_return(
          status: 200,
          body: { elements: [{ id: "REF3", amount: 500 }] }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      refunds = service.fetch_refunds(limit: 10, offset: 5)

      expect(refunds.size).to eq(1)
    end

    it "returns empty array when no refunds exist" do
      stub_request(:get, "#{base_url}/refunds")
        .to_return(
          status: 200,
          body: { elements: [] }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      refunds = service.fetch_refunds

      expect(refunds).to eq([])
    end
  end

  describe "#get_refund" do
    it "returns a specific refund by ID" do
      stub_request(:get, "#{base_url}/refunds/REF123")
        .to_return(
          status: 200,
          body: {
            id: "REF123",
            amount: 1500,
            reason: "customer_request",
            payment: { id: "PAY1" }
          }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      refund = service.get_refund("REF123")

      expect(refund["id"]).to eq("REF123")
      expect(refund["amount"]).to eq(1500)
      expect(refund["reason"]).to eq("customer_request")
    end
  end

  describe "#create_refund" do
    context "with full refund (no amount specified)" do
      it "creates a full refund" do
        stub_request(:post, "#{base_url}/refunds")
          .with(body: hash_including(
            "payment" => { "id" => "PAY123" },
            "reason" => "customer_request"
          ))
          .to_return(
            status: 200,
            body: {
              id: "REF456",
              amount: 5000,
              payment: { id: "PAY123" },
              reason: "customer_request"
            }.to_json,
            headers: { "Content-Type" => "application/json" }
          )

        refund = service.create_refund(payment_id: "PAY123")

        expect(refund["id"]).to eq("REF456")
        expect(refund["amount"]).to eq(5000)
      end
    end

    context "with partial refund" do
      it "creates a partial refund with specified amount" do
        stub_request(:post, "#{base_url}/refunds")
          .with(body: hash_including(
            "payment" => { "id" => "PAY123" },
            "amount" => 2000,
            "reason" => "quality_issue"
          ))
          .to_return(
            status: 200,
            body: {
              id: "REF789",
              amount: 2000,
              payment: { id: "PAY123" },
              reason: "quality_issue"
            }.to_json,
            headers: { "Content-Type" => "application/json" }
          )

        refund = service.create_refund(
          payment_id: "PAY123",
          amount: 2000,
          reason: "quality_issue"
        )

        expect(refund["id"]).to eq("REF789")
        expect(refund["amount"]).to eq(2000)
      end
    end

    it "defaults to customer_request when invalid reason provided" do
      stub_request(:post, "#{base_url}/refunds")
        .with(body: hash_including("reason" => "customer_request"))
        .to_return(
          status: 200,
          body: { id: "REF999", amount: 1000 }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      refund = service.create_refund(payment_id: "PAY1", reason: "invalid_reason")

      expect(refund["id"]).to eq("REF999")
    end
  end

  describe "#create_full_refund" do
    it "delegates to create_refund without amount" do
      stub_request(:post, "#{base_url}/refunds")
        .with(body: ->(body) {
          parsed = JSON.parse(body)
          parsed["payment"]["id"] == "PAY123" && !parsed.key?("amount")
        })
        .to_return(
          status: 200,
          body: { id: "REF111", amount: 3000 }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      refund = service.create_full_refund(payment_id: "PAY123", reason: "wrong_order")

      expect(refund["id"]).to eq("REF111")
    end
  end

  describe "#create_partial_refund" do
    it "creates a partial refund with specified amount" do
      stub_request(:post, "#{base_url}/refunds")
        .with(body: hash_including("amount" => 1500))
        .to_return(
          status: 200,
          body: { id: "REF222", amount: 1500 }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      refund = service.create_partial_refund(
        payment_id: "PAY123",
        amount: 1500,
        reason: "duplicate_charge"
      )

      expect(refund["id"]).to eq("REF222")
      expect(refund["amount"]).to eq(1500)
    end

    it "raises ArgumentError when amount is nil" do
      expect {
        service.create_partial_refund(payment_id: "PAY123", amount: nil)
      }.to raise_error(ArgumentError, "Amount is required for partial refund")
    end

    it "raises ArgumentError when amount is zero or negative" do
      expect {
        service.create_partial_refund(payment_id: "PAY123", amount: 0)
      }.to raise_error(ArgumentError, "Amount must be positive")

      expect {
        service.create_partial_refund(payment_id: "PAY123", amount: -100)
      }.to raise_error(ArgumentError, "Amount must be positive")
    end
  end

  describe "#random_reason" do
    it "returns a valid refund reason" do
      100.times do
        reason = service.random_reason

        expect(described_class::REFUND_REASONS).to include(reason)
      end
    end
  end

  describe "::REFUND_REASONS" do
    it "contains expected refund reasons" do
      expected = %w[customer_request quality_issue wrong_order duplicate_charge]

      expect(described_class::REFUND_REASONS).to match_array(expected)
    end
  end
end
