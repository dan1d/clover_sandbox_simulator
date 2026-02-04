# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Cash Events Integration", :vcr do
  # Load test configuration from .env.json
  let(:merchant_config) { get_merchant_config("QA TEST LOCAL 2") }
  let(:config) do
    return nil unless merchant_config

    c = CloverSandboxSimulator::Configuration.new
    c.merchant_id = merchant_config["CLOVER_MERCHANT_ID"]
    c.api_token = merchant_config["CLOVER_API_TOKEN"]
    c
  end

  describe "CashEventService" do
    describe "#get_cash_events", vcr: { cassette_name: "integration/cash_events/get_cash_events" } do
      it "fetches cash events from Clover" do
        skip "QA TEST LOCAL 2 merchant not configured" unless merchant_config

        service = CloverSandboxSimulator::Services::Clover::CashEventService.new(config: config)
        events = service.get_cash_events

        expect(events).to be_an(Array)
        events.each do |event|
          expect(event).to have_key("id")
          expect(event).to have_key("type")
          expect(event).to have_key("amountChange")
        end
      end
    end

    describe "#create_cash_event", vcr: { cassette_name: "integration/cash_events/create_cash_event" } do
      it "creates a cash event (may not be supported in sandbox)" do
        skip "QA TEST LOCAL 2 merchant not configured" unless merchant_config

        service = CloverSandboxSimulator::Services::Clover::CashEventService.new(config: config)
        employee_service = CloverSandboxSimulator::Services::Clover::EmployeeService.new(config: config)

        # Get an employee first
        employees = employee_service.get_employees
        skip "No employees found in sandbox" if employees.empty?

        employee_id = employees.first["id"]

        result = service.create_cash_event(
          type: "ADD",
          amount: 1000,
          employee_id: employee_id,
          note: "Test cash add"
        )

        # Skip if we got a simulated response (sandbox limitation)
        skip "Cash event creation not supported in sandbox (simulated response)" if result["simulated"]

        expect(result).to have_key("id")
        expect(result["type"]).to eq("ADD")
      end
    end

    describe "#open_drawer", vcr: { cassette_name: "integration/cash_events/open_drawer" } do
      it "opens a cash drawer with starting cash (may not be supported in sandbox)" do
        skip "QA TEST LOCAL 2 merchant not configured" unless merchant_config

        service = CloverSandboxSimulator::Services::Clover::CashEventService.new(config: config)
        employee_service = CloverSandboxSimulator::Services::Clover::EmployeeService.new(config: config)

        employees = employee_service.get_employees
        skip "No employees found in sandbox" if employees.empty?

        employee_id = employees.first["id"]

        result = service.open_drawer(employee_id: employee_id, starting_cash: 20000)

        # Skip if we got a simulated response (sandbox limitation)
        skip "Cash event creation not supported in sandbox (simulated response)" if result["simulated"]

        expect(result).to have_key("id")
        expect(result["type"]).to eq("OPEN")
      end
    end

    describe "#calculate_drawer_total" do
      it "calculates the total from events" do
        # This test doesn't need API access
        service = CloverSandboxSimulator::Services::Clover::CashEventService.allocate

        events = [
          { "amountChange" => 20000 },
          { "amountChange" => 1500 },
          { "amountChange" => -500 }
        ]

        total = service.calculate_drawer_total(events)

        expect(total).to eq(21000)
      end
    end
  end
end
