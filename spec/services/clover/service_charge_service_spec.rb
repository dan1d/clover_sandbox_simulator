# frozen_string_literal: true

require "spec_helper"

RSpec.describe CloverSandboxSimulator::Services::Clover::ServiceChargeService do
  before { stub_clover_credentials }

  let(:service) { described_class.new }
  let(:base_url) { "https://sandbox.dev.clover.com/v3/merchants/TEST_MERCHANT_ID" }

  describe "#get_service_charges" do
    it "fetches all service charges" do
      stub_request(:get, "#{base_url}/default_service_charge")
        .to_return(
          status: 200,
          body: {
            "elements" => [
              { "id" => "SC1", "name" => "Auto Gratuity", "percentageDecimal" => 1800, "enabled" => true },
              { "id" => "SC2", "name" => "Large Party Fee", "percentageDecimal" => 2000, "enabled" => true }
            ]
          }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      result = service.get_service_charges

      expect(result).to be_an(Array)
      expect(result.size).to eq(2)
      expect(result.first["name"]).to eq("Auto Gratuity")
    end
  end

  describe "#create_service_charge" do
    it "creates a new service charge" do
      stub_request(:post, "#{base_url}/default_service_charge")
        .with(body: hash_including(
          "name" => "Auto Gratuity 18%",
          "percentageDecimal" => 1800,
          "enabled" => true
        ))
        .to_return(
          status: 200,
          body: { id: "SC_NEW", name: "Auto Gratuity 18%", percentageDecimal: 1800, enabled: true }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      result = service.create_service_charge(
        name: "Auto Gratuity 18%",
        percentage: 18.0
      )

      expect(result["id"]).to eq("SC_NEW")
      expect(result["name"]).to eq("Auto Gratuity 18%")
      expect(result["percentageDecimal"]).to eq(1800)
    end
  end

  describe "#apply_service_charge_to_order" do
    it "applies a service charge to an order when ID is provided" do
      stub_request(:post, "#{base_url}/orders/ORDER123/service_charge")
        .with(body: hash_including(
          "id" => "SC1",
          "name" => "Auto Gratuity",
          "percentageDecimal" => 1800
        ))
        .to_return(
          status: 200,
          body: { id: "OSC1", name: "Auto Gratuity", percentageDecimal: 1800 }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      result = service.apply_service_charge_to_order(
        "ORDER123",
        name: "Auto Gratuity",
        percentage: 18.0,
        service_charge_id: "SC1"
      )

      expect(result["id"]).to eq("OSC1")
      expect(result["name"]).to eq("Auto Gratuity")
    end

    it "finds existing service charge when ID is not provided" do
      # Stub the lookup for existing service charges
      stub_request(:get, "#{base_url}/default_service_charge")
        .to_return(
          status: 200,
          body: {
            "elements" => [
              { "id" => "SC_EXISTING", "name" => "Auto Gratuity", "percentageDecimal" => 1800 }
            ]
          }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      stub_request(:post, "#{base_url}/orders/ORDER123/service_charge")
        .with(body: hash_including(
          "id" => "SC_EXISTING",
          "name" => "auto gratuity"
        ))
        .to_return(
          status: 200,
          body: { id: "OSC1", name: "Auto Gratuity", percentageDecimal: 1800 }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      result = service.apply_service_charge_to_order(
        "ORDER123",
        name: "auto gratuity",
        percentage: 18.0
      )

      expect(result["id"]).to eq("OSC1")
    end
  end

  describe "#get_auto_gratuity_charge" do
    it "returns the auto-gratuity service charge if it exists" do
      stub_request(:get, "#{base_url}/default_service_charge")
        .to_return(
          status: 200,
          body: {
            "elements" => [
              { "id" => "SC1", "name" => "Auto Gratuity", "percentageDecimal" => 1800, "enabled" => true }
            ]
          }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      result = service.get_auto_gratuity_charge

      expect(result).not_to be_nil
      expect(result["name"]).to eq("Auto Gratuity")
    end

    it "returns nil if no auto-gratuity charge exists" do
      stub_request(:get, "#{base_url}/default_service_charge")
        .to_return(
          status: 200,
          body: { "elements" => [] }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      result = service.get_auto_gratuity_charge

      expect(result).to be_nil
    end
  end
end
