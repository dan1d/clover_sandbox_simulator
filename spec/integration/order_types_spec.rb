# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Order Types Integration", :vcr do
  # Load test configuration from .env.json
  let(:merchant_config) { get_merchant_config("QA TEST LOCAL 2") }
  let(:config) do
    return nil unless merchant_config

    c = CloverSandboxSimulator::Configuration.new
    c.merchant_id = merchant_config["CLOVER_MERCHANT_ID"]
    c.api_token = merchant_config["CLOVER_API_TOKEN"]
    c
  end

  describe "OrderTypeService" do
    describe "#get_order_types", vcr: { cassette_name: "integration/order_types/get_order_types" } do
      it "fetches order types from Clover" do
        skip "QA TEST LOCAL 2 merchant not configured" unless merchant_config

        service = CloverSandboxSimulator::Services::Clover::OrderTypeService.new(config: config)
        types = service.get_order_types

        expect(types).to be_an(Array)
        # Should have at least the default order types
        types.each do |order_type|
          expect(order_type).to have_key("id")
          expect(order_type).to have_key("label")
        end
      end
    end

    describe "#create_order_type", vcr: { cassette_name: "integration/order_types/create_order_type" } do
      it "creates a new order type" do
        skip "QA TEST LOCAL 2 merchant not configured" unless merchant_config

        service = CloverSandboxSimulator::Services::Clover::OrderTypeService.new(config: config)
        # Use a unique name to avoid conflicts
        unique_name = "Test Order Type #{Time.now.to_i}"

        result = service.create_order_type(
          label: unique_name,
          taxable: true,
          fee: 100,
          min_order_amount: 500
        )

        expect(result).to have_key("id")
        expect(result["label"]).to eq(unique_name)
      end
    end

    describe "#setup_default_order_types", vcr: { cassette_name: "integration/order_types/setup_default" } do
      it "sets up default order types idempotently" do
        skip "QA TEST LOCAL 2 merchant not configured" unless merchant_config

        service = CloverSandboxSimulator::Services::Clover::OrderTypeService.new(config: config)
        result = service.setup_default_order_types

        expect(result).to be_an(Array)
        expect(result.size).to be >= 1

        labels = result.map { |ot| ot["label"] }
        # Should include common order types
        expect(labels.any? { |l| l&.include?("Dine In") || l&.include?("Takeout") || l&.include?("Delivery") }).to be true
      end
    end
  end
end
