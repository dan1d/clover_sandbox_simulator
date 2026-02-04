# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Tax Rates Integration", :vcr do
  # Load test configuration from .env.json
  let(:merchant_config) { get_merchant_config("QA TEST LOCAL 2") }
  let(:config) do
    return nil unless merchant_config

    c = CloverSandboxSimulator::Configuration.new
    c.merchant_id = merchant_config["CLOVER_MERCHANT_ID"]
    c.api_token = merchant_config["CLOVER_API_TOKEN"]
    c
  end

  describe "TaxService" do
    describe "#get_tax_rates", vcr: { cassette_name: "integration/tax_rates/get_tax_rates" } do
      it "fetches tax rates from Clover" do
        skip "QA TEST LOCAL 2 merchant not configured" unless merchant_config

        service = CloverSandboxSimulator::Services::Clover::TaxService.new(config: config)
        rates = service.get_tax_rates

        expect(rates).to be_an(Array)
        rates.each do |rate|
          expect(rate).to have_key("id")
          expect(rate).to have_key("name")
          expect(rate).to have_key("rate")
        end
      end
    end

    describe "#create_tax_rate", vcr: { cassette_name: "integration/tax_rates/create_tax_rate" } do
      it "creates a new tax rate" do
        skip "QA TEST LOCAL 2 merchant not configured" unless merchant_config

        service = CloverSandboxSimulator::Services::Clover::TaxService.new(config: config)
        unique_name = "Test Tax #{Time.now.to_i}"

        result = service.create_tax_rate(
          name: unique_name,
          rate: 5.5,
          is_default: false
        )

        expect(result).to have_key("id")
        expect(result["name"]).to eq(unique_name)
        # Rate is stored as basis points (5.5% = 550000)
        expect(result["rate"]).to eq(550_000)
      end
    end

    describe "#setup_default_tax_rates", vcr: { cassette_name: "integration/tax_rates/setup_default" } do
      it "sets up default tax rates idempotently" do
        skip "QA TEST LOCAL 2 merchant not configured" unless merchant_config

        service = CloverSandboxSimulator::Services::Clover::TaxService.new(config: config)
        result = service.setup_default_tax_rates

        expect(result).to be_an(Array)
        expect(result.size).to be >= 1

        names = result.map { |r| r["name"] }
        expect(names).to include("Sales Tax")
      end
    end

    describe "#associate_item_with_tax_rate", vcr: { cassette_name: "integration/tax_rates/associate_item" } do
      it "associates an item with a tax rate" do
        skip "QA TEST LOCAL 2 merchant not configured" unless merchant_config

        service = CloverSandboxSimulator::Services::Clover::TaxService.new(config: config)
        inventory_service = CloverSandboxSimulator::Services::Clover::InventoryService.new(config: config)

        # Get existing items and tax rates
        items = inventory_service.get_items
        tax_rates = service.get_tax_rates

        skip "No items found in sandbox" if items.empty?
        skip "No tax rates found in sandbox" if tax_rates.empty?

        item_id = items.first["id"]
        tax_rate_id = tax_rates.first["id"]

        result = service.associate_item_with_tax_rate(item_id, tax_rate_id)

        expect(result).to be_truthy
      end
    end

    describe "#get_tax_rates_for_item", vcr: { cassette_name: "integration/tax_rates/get_item_tax_rates" } do
      it "fetches tax rates for a specific item (may not be supported in sandbox)" do
        skip "QA TEST LOCAL 2 merchant not configured" unless merchant_config

        service = CloverSandboxSimulator::Services::Clover::TaxService.new(config: config)
        inventory_service = CloverSandboxSimulator::Services::Clover::InventoryService.new(config: config)

        items = inventory_service.get_items
        skip "No items found in sandbox" if items.empty?

        item_id = items.first["id"]

        begin
          rates = service.get_tax_rates_for_item(item_id)
          expect(rates).to be_an(Array)
        rescue CloverSandboxSimulator::ApiError => e
          # Sandbox may not support this endpoint
          skip "Getting tax rates for item not supported in sandbox: #{e.message}" if e.message.include?("405")
          raise
        end
      end
    end
  end
end
