# frozen_string_literal: true

require "spec_helper"

RSpec.describe CloverSandboxSimulator::Services::Clover::OrderTypeService do
  let(:config) { create_test_config }
  let(:service) { described_class.new(config: config) }
  let(:base_url) { "https://sandbox.dev.clover.com/v3/merchants/#{config.merchant_id}" }

  describe "#get_order_types" do
    it "fetches all order types" do
      stub_request(:get, "#{base_url}/order_types")
        .to_return(body: {
          elements: [
            { id: "OT1", label: "Dine In", taxable: true },
            { id: "OT2", label: "Takeout", taxable: true },
            { id: "OT3", label: "Delivery", taxable: true, fee: 200 }
          ]
        }.to_json)

      types = service.get_order_types

      expect(types.size).to eq(3)
      expect(types.map { |t| t["label"] }).to include("Dine In", "Takeout", "Delivery")
    end
  end

  describe "#create_order_type" do
    it "creates a new order type" do
      stub_request(:post, "#{base_url}/order_types")
        .with(body: hash_including("label" => "Catering", "taxable" => true, "fee" => 500))
        .to_return(body: {
          id: "OT4",
          label: "Catering",
          taxable: true,
          fee: 500
        }.to_json)

      result = service.create_order_type(label: "Catering", taxable: true, fee: 500)

      expect(result["id"]).to eq("OT4")
      expect(result["label"]).to eq("Catering")
    end
  end

  describe "#set_order_type" do
    it "sets order type for an order" do
      stub_request(:post, "#{base_url}/orders/ORDER123")
        .with(body: hash_including("orderType" => { "id" => "OT1" }))
        .to_return(body: {
          id: "ORDER123",
          orderType: { id: "OT1", label: "Dine In" }
        }.to_json)

      result = service.set_order_type("ORDER123", "OT1")

      expect(result["orderType"]["id"]).to eq("OT1")
    end
  end

  describe "#setup_default_order_types" do
    it "creates missing order types and skips existing ones" do
      # First call returns existing types
      stub_request(:get, "#{base_url}/order_types")
        .to_return(body: {
          elements: [
            { id: "OT1", label: "Dine In", taxable: true }
          ]
        }.to_json)

      # Should create Takeout, Delivery, Curbside Pickup, and Catering (4 new types)
      stub_request(:post, "#{base_url}/order_types")
        .to_return { |request|
          body = JSON.parse(request.body)
          { body: { id: "OT_NEW", label: body["label"] }.to_json }
        }

      result = service.setup_default_order_types

      expect(result.size).to eq(5) # 1 existing + 4 new = 5 total defaults
    end
  end
end
