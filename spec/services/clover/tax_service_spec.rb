# frozen_string_literal: true

require "spec_helper"

RSpec.describe CloverSandboxSimulator::Services::Clover::TaxService do
  before { stub_clover_credentials }

  let(:service) { described_class.new }
  let(:base_url) { "https://sandbox.dev.clover.com/v3/merchants/TEST_MERCHANT_ID" }

  let(:tax_rates_response) do
    [
      { "id" => "TAX1", "name" => "Sales Tax", "rate" => 825_000, "isDefault" => false },
      { "id" => "TAX2", "name" => "State Tax", "rate" => 600_000, "isDefault" => true },
      { "id" => "TAX3", "name" => "Local Tax", "rate" => 225_000, "isDefault" => false }
    ]
  end

  describe "#get_tax_rates" do
    it "fetches all tax rates from the API" do
      stub_request(:get, "#{base_url}/tax_rates")
        .to_return(
          status: 200,
          body: { elements: tax_rates_response }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      rates = service.get_tax_rates

      expect(rates.size).to eq(3)
      expect(rates.first["name"]).to eq("Sales Tax")
    end

    it "returns empty array when no tax rates exist" do
      stub_request(:get, "#{base_url}/tax_rates")
        .to_return(
          status: 200,
          body: { elements: [] }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      rates = service.get_tax_rates

      expect(rates).to eq([])
    end

    it "handles missing elements key in response" do
      stub_request(:get, "#{base_url}/tax_rates")
        .to_return(
          status: 200,
          body: {}.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      rates = service.get_tax_rates

      expect(rates).to eq([])
    end

    it "handles nil response" do
      stub_request(:get, "#{base_url}/tax_rates")
        .to_return(
          status: 200,
          body: "",
          headers: { "Content-Type" => "application/json" }
        )

      rates = service.get_tax_rates

      expect(rates).to eq([])
    end
  end

  describe "#default_tax_rate" do
    it "returns the tax rate marked as default" do
      stub_request(:get, "#{base_url}/tax_rates")
        .to_return(
          status: 200,
          body: { elements: tax_rates_response }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      default_rate = service.default_tax_rate

      expect(default_rate["id"]).to eq("TAX2")
      expect(default_rate["name"]).to eq("State Tax")
      expect(default_rate["isDefault"]).to be true
    end

    it "returns first rate when no default is set" do
      rates_without_default = [
        { "id" => "TAX1", "name" => "Sales Tax", "rate" => 825_000, "isDefault" => false },
        { "id" => "TAX2", "name" => "State Tax", "rate" => 600_000, "isDefault" => false }
      ]

      stub_request(:get, "#{base_url}/tax_rates")
        .to_return(
          status: 200,
          body: { elements: rates_without_default }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      default_rate = service.default_tax_rate

      expect(default_rate["id"]).to eq("TAX1")
    end

    it "returns nil when no tax rates exist" do
      stub_request(:get, "#{base_url}/tax_rates")
        .to_return(
          status: 200,
          body: { elements: [] }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      default_rate = service.default_tax_rate

      expect(default_rate).to be_nil
    end

    it "prioritizes isDefault true even if not first in list" do
      rates_with_default_last = [
        { "id" => "TAX1", "name" => "Tax A", "rate" => 100_000, "isDefault" => false },
        { "id" => "TAX2", "name" => "Tax B", "rate" => 200_000, "isDefault" => false },
        { "id" => "TAX3", "name" => "Tax C", "rate" => 300_000, "isDefault" => true }
      ]

      stub_request(:get, "#{base_url}/tax_rates")
        .to_return(
          status: 200,
          body: { elements: rates_with_default_last }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      default_rate = service.default_tax_rate

      expect(default_rate["id"]).to eq("TAX3")
    end
  end

  describe "#create_tax_rate" do
    it "creates a tax rate with correct basis points conversion" do
      # 8.25% should become 825000 basis points
      stub_request(:post, "#{base_url}/tax_rates")
        .with(body: hash_including(
          "name" => "Sales Tax",
          "rate" => 825_000,
          "isDefault" => false,
          "taxType" => "VAT_EXEMPT"
        ))
        .to_return(
          status: 200,
          body: { id: "NEW_TAX", name: "Sales Tax", rate: 825_000 }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      result = service.create_tax_rate(name: "Sales Tax", rate: 8.25)

      expect(result["id"]).to eq("NEW_TAX")
      expect(result["name"]).to eq("Sales Tax")
    end

    it "creates a default tax rate when is_default is true" do
      stub_request(:post, "#{base_url}/tax_rates")
        .with(body: hash_including(
          "name" => "Default Tax",
          "isDefault" => true
        ))
        .to_return(
          status: 200,
          body: { id: "NEW_TAX", name: "Default Tax", isDefault: true }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      result = service.create_tax_rate(name: "Default Tax", rate: 7.0, is_default: true)

      expect(result["isDefault"]).to be true
    end

    it "handles zero tax rate" do
      stub_request(:post, "#{base_url}/tax_rates")
        .with(body: hash_including(
          "name" => "Tax Exempt",
          "rate" => 0
        ))
        .to_return(
          status: 200,
          body: { id: "ZERO_TAX", name: "Tax Exempt", rate: 0 }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      result = service.create_tax_rate(name: "Tax Exempt", rate: 0)

      expect(result["rate"]).to eq(0)
    end

    it "correctly converts decimal rates to basis points" do
      # Testing various rates for correct conversion
      test_cases = [
        { rate: 10.0, expected_basis: 1_000_000 },
        { rate: 5.5, expected_basis: 550_000 },
        { rate: 0.25, expected_basis: 25_000 }
      ]

      test_cases.each do |test_case|
        stub_request(:post, "#{base_url}/tax_rates")
          .with(body: hash_including("rate" => test_case[:expected_basis]))
          .to_return(
            status: 200,
            body: { id: "TAX", rate: test_case[:expected_basis] }.to_json,
            headers: { "Content-Type" => "application/json" }
          )

        result = service.create_tax_rate(name: "Test", rate: test_case[:rate])

        expect(result["rate"]).to eq(test_case[:expected_basis])
      end
    end
  end

  describe "#delete_tax_rate" do
    it "deletes a tax rate by ID" do
      stub_request(:delete, "#{base_url}/tax_rates/TAX1")
        .to_return(
          status: 200,
          body: "",
          headers: { "Content-Type" => "application/json" }
        )

      expect { service.delete_tax_rate("TAX1") }.not_to raise_error
    end

    it "raises error when tax rate does not exist" do
      stub_request(:delete, "#{base_url}/tax_rates/INVALID")
        .to_return(
          status: 404,
          body: { message: "Tax rate not found" }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      expect { service.delete_tax_rate("INVALID") }
        .to raise_error(CloverSandboxSimulator::ApiError, /404/)
    end
  end

  describe "#calculate_tax" do
    it "calculates tax using config tax rate when no rate provided" do
      # Config tax rate is 8.25%
      # subtotal of 1000 cents = 82.5 cents, rounded to 83
      result = service.calculate_tax(1000)

      expect(result).to eq(83)
    end

    it "calculates tax using provided tax rate" do
      # 10% of 1000 = 100
      result = service.calculate_tax(1000, 10.0)

      expect(result).to eq(100)
    end

    it "rounds to nearest cent" do
      # 8.25% of 1234 = 101.805, should round to 102
      result = service.calculate_tax(1234)

      expect(result).to eq(102)
    end

    it "returns zero for zero subtotal" do
      result = service.calculate_tax(0)

      expect(result).to eq(0)
    end

    it "returns zero for zero tax rate" do
      result = service.calculate_tax(1000, 0)

      expect(result).to eq(0)
    end

    it "handles small amounts correctly" do
      # 8.25% of 10 = 0.825, should round to 1
      result = service.calculate_tax(10)

      expect(result).to eq(1)
    end

    it "handles large amounts correctly" do
      # 8.25% of 1,000,000 = 82,500
      result = service.calculate_tax(1_000_000)

      expect(result).to eq(82_500)
    end

    it "handles fractional tax rates" do
      # 8.375% of 1000 = 83.75, rounds to 84
      result = service.calculate_tax(1000, 8.375)

      expect(result).to eq(84)
    end

    it "handles negative amounts" do
      # Negative subtotals might occur for refunds
      # -8.25% of 1000 = -82.5, rounds to -83
      result = service.calculate_tax(-1000)

      expect(result).to eq(-83)
    end
  end

  describe "#get_items_for_tax_rate" do
    it "fetches all items associated with a tax rate" do
      stub_request(:get, "#{base_url}/tax_rates/TAX1/items")
        .to_return(
          status: 200,
          body: { elements: [
            { "id" => "ITEM1", "name" => "Burger" },
            { "id" => "ITEM2", "name" => "Fries" }
          ] }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      items = service.get_items_for_tax_rate("TAX1")

      expect(items.size).to eq(2)
      expect(items.first["name"]).to eq("Burger")
    end
  end

  describe "#get_tax_rates_for_item" do
    it "fetches all tax rates associated with an item" do
      stub_request(:get, "#{base_url}/items/ITEM1/tax_rates")
        .to_return(
          status: 200,
          body: { elements: [
            { "id" => "TAX1", "name" => "State Tax", "rate" => 600_000 },
            { "id" => "TAX2", "name" => "Local Tax", "rate" => 225_000 }
          ] }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      rates = service.get_tax_rates_for_item("ITEM1")

      expect(rates.size).to eq(2)
      expect(rates.map { |r| r["name"] }).to include("State Tax", "Local Tax")
    end
  end

  describe "#associate_item_with_tax_rate" do
    it "associates an item with a tax rate" do
      stub_request(:post, "#{base_url}/tax_rate_items")
        .with(body: hash_including(
          "elements" => [{ "item" => { "id" => "ITEM1" }, "taxRate" => { "id" => "TAX1" } }]
        ))
        .to_return(
          status: 200,
          body: { elements: [{ "item" => { "id" => "ITEM1" }, "taxRate" => { "id" => "TAX1" } }] }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      result = service.associate_item_with_tax_rate("ITEM1", "TAX1")

      expect(result).to be_truthy
    end
  end

  describe "#remove_item_from_tax_rate" do
    it "removes an item from a tax rate" do
      stub_request(:delete, "#{base_url}/tax_rate_items")
        .with(query: { item: "ITEM1", taxRate: "TAX1" })
        .to_return(status: 200, body: "")

      expect { service.remove_item_from_tax_rate("ITEM1", "TAX1") }.not_to raise_error
    end
  end

  describe "#calculate_item_tax" do
    it "calculates tax for an item based on its assigned tax rates" do
      # Mock get_tax_rates_for_item to return two rates totaling 8.25%
      stub_request(:get, "#{base_url}/items/ITEM1/tax_rates")
        .to_return(
          status: 200,
          body: { elements: [
            { "id" => "TAX1", "name" => "State Tax", "rate" => 600_000 },  # 6%
            { "id" => "TAX2", "name" => "Local Tax", "rate" => 225_000 }   # 2.25%
          ] }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      # 8.25% of 1000 = 82.5, rounds to 83
      result = service.calculate_item_tax("ITEM1", 1000)

      expect(result).to eq(83)
    end

    it "returns zero for items with no tax rates" do
      stub_request(:get, "#{base_url}/items/ITEM1/tax_rates")
        .to_return(
          status: 200,
          body: { elements: [] }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      result = service.calculate_item_tax("ITEM1", 1000)

      expect(result).to eq(0)
    end
  end

  describe "#setup_default_tax_rates" do
    it "creates standard restaurant tax rates if they don't exist" do
      # First call - check existing (empty)
      stub_request(:get, "#{base_url}/tax_rates")
        .to_return(
          status: 200,
          body: { elements: [] }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      # Create the tax rates
      stub_request(:post, "#{base_url}/tax_rates")
        .to_return { |request|
          body = JSON.parse(request.body)
          { body: { id: "TAX_NEW", name: body["name"], rate: body["rate"] }.to_json }
        }

      result = service.setup_default_tax_rates

      expect(result).to be_an(Array)
      expect(result.size).to be >= 1
    end

    it "skips existing tax rates (idempotent)" do
      # Return existing tax rates that match default names
      stub_request(:get, "#{base_url}/tax_rates")
        .to_return(
          status: 200,
          body: { elements: [
            { "id" => "TAX1", "name" => "Sales Tax", "rate" => 825_000 },
            { "id" => "TAX2", "name" => "Alcohol Tax", "rate" => 1_000_000 },
            { "id" => "TAX3", "name" => "Prepared Food Tax", "rate" => 825_000 }
          ] }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      # No POST should be made since all defaults exist
      result = service.setup_default_tax_rates

      expect(result).to be_an(Array)
      expect(result.size).to eq(3)
    end
  end

  describe "API error handling" do
    it "raises ApiError on 401 Unauthorized" do
      stub_request(:get, "#{base_url}/tax_rates")
        .to_return(
          status: 401,
          body: { message: "Invalid token" }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      expect { service.get_tax_rates }
        .to raise_error(CloverSandboxSimulator::ApiError, /401/)
    end

    it "raises ApiError on 500 Internal Server Error" do
      stub_request(:get, "#{base_url}/tax_rates")
        .to_return(
          status: 500,
          body: { message: "Internal server error" }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      expect { service.get_tax_rates }
        .to raise_error(CloverSandboxSimulator::ApiError, /500/)
    end

    it "raises error on network timeout" do
      stub_request(:get, "#{base_url}/tax_rates")
        .to_timeout

      # Note: Network timeouts bubble up through BaseService error handling.
      # Testing that the service doesn't silently swallow network errors.
      expect { service.get_tax_rates }.to raise_error(StandardError)
    end
  end
end
