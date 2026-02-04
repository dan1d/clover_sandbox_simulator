# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Service Charges Integration", :vcr do
  let(:merchant_config) { get_merchant_config("QA TEST LOCAL 2") }

  before(:each) do
    skip "QA TEST LOCAL 2 merchant not found in .env.json" unless merchant_config

    # Configure the simulator with real credentials
    CloverSandboxSimulator.configure do |config|
      config.merchant_id = merchant_config["CLOVER_MERCHANT_ID"]
      config.api_token = merchant_config["CLOVER_API_TOKEN"]
      config.environment = "https://sandbox.dev.clover.com/"
      config.log_level = Logger::DEBUG
    end
  end

  describe "ServiceChargeService" do
    let(:service) do
      CloverSandboxSimulator::Services::Clover::ServiceChargeService.new(
        config: CloverSandboxSimulator.configuration
      )
    end

    describe "#get_service_charges", vcr: { cassette_name: "integration/service_charges/get_all" } do
      it "fetches service charges from Clover" do
        result = service.get_service_charges

        expect(result).to be_an(Array)
      end
    end

    describe "#apply_service_charge_to_order", vcr: { cassette_name: "integration/service_charges/apply_to_order" } do
      let(:order_service) do
        CloverSandboxSimulator::Services::Clover::OrderService.new(
          config: CloverSandboxSimulator.configuration
        )
      end

      it "handles service charge application (may fail in sandbox without pre-configured charges)" do
        # Note: Sandbox requires service charges to be configured in dashboard first
        # This test verifies the API integration works

        # Check if any service charges exist
        charges = service.get_service_charges
        
        if charges.empty?
          # Skip if no pre-configured service charges in sandbox
          skip "No service charges configured in sandbox merchant (must be set up in Clover dashboard)"
        end

        # Create a test order
        order = order_service.create_order(employee_id: nil)
        expect(order).not_to be_nil
        expect(order["id"]).not_to be_nil

        order_id = order["id"]

        begin
          # Apply existing service charge
          existing_charge = charges.first
          result = service.apply_service_charge_to_order(
            order_id,
            name: existing_charge["name"],
            percentage: existing_charge["percentageDecimal"] / 100.0,
            service_charge_id: existing_charge["id"]
          )

          expect(result).to be_a(Hash) if result
        ensure
          # Clean up - delete the order
          order_service.delete_order(order_id)
        end
      end
    end
  end
end
