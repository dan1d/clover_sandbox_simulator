# frozen_string_literal: true

require "spec_helper"

RSpec.describe CloverSandboxSimulator::Services::Clover::CashEventService do
  let(:config) { create_test_config }
  let(:service) { described_class.new(config: config) }
  let(:base_url) { "https://sandbox.dev.clover.com/v3/merchants/#{config.merchant_id}" }
  let(:employee_id) { "EMP123" }

  describe "#get_cash_events" do
    it "fetches all cash events" do
      stub_request(:get, "#{base_url}/cash_events")
        .with(query: { limit: 100 })
        .to_return(body: {
          elements: [
            { id: "CE1", type: "OPEN", amountChange: 20000, timestamp: 1704067200000 },
            { id: "CE2", type: "PAY", amountChange: 1500, timestamp: 1704070800000 },
            { id: "CE3", type: "PAY", amountChange: 2500, timestamp: 1704074400000 }
          ]
        }.to_json)

      events = service.get_cash_events

      expect(events.size).to eq(3)
      expect(events.map { |e| e["type"] }).to include("OPEN", "PAY")
    end
  end

  describe "#create_cash_event" do
    it "creates a cash event" do
      stub_request(:post, "#{base_url}/cash_events")
        .with(body: hash_including(
          "type" => "ADD",
          "amountChange" => 5000,
          "employee" => { "id" => employee_id }
        ))
        .to_return(body: {
          id: "CE_NEW",
          type: "ADD",
          amountChange: 5000
        }.to_json)

      result = service.create_cash_event(type: "ADD", amount: 5000, employee_id: employee_id)

      expect(result["id"]).to eq("CE_NEW")
      expect(result["type"]).to eq("ADD")
    end

    it "raises error for invalid event type" do
      expect {
        service.create_cash_event(type: "INVALID", amount: 100, employee_id: employee_id)
      }.to raise_error(ArgumentError, /Invalid cash event type/)
    end
  end

  describe "#open_drawer" do
    it "creates an OPEN event with starting cash" do
      stub_request(:post, "#{base_url}/cash_events")
        .with(body: hash_including(
          "type" => "OPEN",
          "amountChange" => 20000,
          "note" => "Drawer opened"
        ))
        .to_return(body: { id: "CE1", type: "OPEN", amountChange: 20000 }.to_json)

      result = service.open_drawer(employee_id: employee_id)

      expect(result["type"]).to eq("OPEN")
      expect(result["amountChange"]).to eq(20000)
    end

    it "accepts custom starting cash amount" do
      stub_request(:post, "#{base_url}/cash_events")
        .with(body: hash_including("amountChange" => 30000))
        .to_return(body: { id: "CE1", type: "OPEN", amountChange: 30000 }.to_json)

      result = service.open_drawer(employee_id: employee_id, starting_cash: 30000)

      expect(result["amountChange"]).to eq(30000)
    end
  end

  describe "#close_drawer" do
    it "creates a CLOSE event with final amount" do
      stub_request(:post, "#{base_url}/cash_events")
        .with(body: hash_including(
          "type" => "CLOSE",
          "amountChange" => 45000,
          "note" => "Drawer closed"
        ))
        .to_return(body: { id: "CE1", type: "CLOSE", amountChange: 45000 }.to_json)

      result = service.close_drawer(employee_id: employee_id, final_amount: 45000)

      expect(result["type"]).to eq("CLOSE")
    end
  end

  describe "#add_cash" do
    it "creates an ADD event" do
      stub_request(:post, "#{base_url}/cash_events")
        .with(body: hash_including("type" => "ADD", "amountChange" => 10000))
        .to_return(body: { id: "CE1", type: "ADD", amountChange: 10000 }.to_json)

      result = service.add_cash(employee_id: employee_id, amount: 10000, note: "Extra cash")

      expect(result["type"]).to eq("ADD")
    end
  end

  describe "#remove_cash" do
    it "creates a REMOVE event with negative amount" do
      stub_request(:post, "#{base_url}/cash_events")
        .with(body: hash_including("type" => "REMOVE", "amountChange" => -5000))
        .to_return(body: { id: "CE1", type: "REMOVE", amountChange: -5000 }.to_json)

      result = service.remove_cash(employee_id: employee_id, amount: 5000)

      expect(result["type"]).to eq("REMOVE")
    end
  end

  describe "#record_cash_payment" do
    it "creates a PAY event" do
      stub_request(:post, "#{base_url}/cash_events")
        .with(body: hash_including("type" => "PAY", "amountChange" => 2500))
        .to_return(body: { id: "CE1", type: "PAY", amountChange: 2500 }.to_json)

      result = service.record_cash_payment(employee_id: employee_id, amount: 2500)

      expect(result["type"]).to eq("PAY")
    end
  end

  describe "#record_cash_refund" do
    it "creates a REFUND event with negative amount" do
      stub_request(:post, "#{base_url}/cash_events")
        .with(body: hash_including("type" => "REFUND", "amountChange" => -500))
        .to_return(body: { id: "CE1", type: "REFUND", amountChange: -500 }.to_json)

      result = service.record_cash_refund(employee_id: employee_id, amount: 500)

      expect(result["type"]).to eq("REFUND")
    end
  end

  describe "#calculate_drawer_total" do
    it "sums all amount changes from events" do
      events = [
        { "amountChange" => 20000 },  # OPEN
        { "amountChange" => 1500 },   # PAY
        { "amountChange" => 2500 },   # PAY
        { "amountChange" => -500 },   # REFUND
        { "amountChange" => -5000 }   # REMOVE
      ]

      total = service.calculate_drawer_total(events)

      expect(total).to eq(18500) # 20000 + 1500 + 2500 - 500 - 5000
    end
  end
end
