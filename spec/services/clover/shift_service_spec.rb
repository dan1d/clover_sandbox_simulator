# frozen_string_literal: true

require "spec_helper"

RSpec.describe CloverSandboxSimulator::Services::Clover::ShiftService do
  before { stub_clover_credentials }

  let(:service) { described_class.new }
  let(:base_url) { "https://sandbox.dev.clover.com/v3/merchants/TEST_MERCHANT_ID" }

  describe "#get_shifts" do
    it "fetches all shifts" do
      stub_request(:get, "#{base_url}/shifts")
        .with(query: { limit: 100 })
        .to_return(
          status: 200,
          body: {
            "elements" => [
              { "id" => "SHIFT1", "employee" => { "id" => "EMP1" }, "inTime" => 1700000000000, "outTime" => 1700028800000 },
              { "id" => "SHIFT2", "employee" => { "id" => "EMP2" }, "inTime" => 1700000000000 }
            ]
          }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      result = service.get_shifts

      expect(result).to be_an(Array)
      expect(result.size).to eq(2)
    end
  end

  describe "#clock_in" do
    it "creates a shift for an employee" do
      stub_request(:post, "#{base_url}/shifts")
        .with(body: hash_including(
          "employee" => { "id" => "EMP1" }
        ))
        .to_return(
          status: 200,
          body: { id: "SHIFT_NEW", employee: { id: "EMP1" }, inTime: 1700000000000 }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      result = service.clock_in(employee_id: "EMP1")

      expect(result["id"]).to eq("SHIFT_NEW")
      expect(result.dig("employee", "id")).to eq("EMP1")
      expect(result["inTime"]).not_to be_nil
    end
  end

  describe "#clock_out" do
    it "ends a shift for an employee" do
      stub_request(:post, "#{base_url}/shifts/SHIFT1")
        .with(body: hash_including("outTime"))
        .to_return(
          status: 200,
          body: { id: "SHIFT1", employee: { id: "EMP1" }, inTime: 1700000000000, outTime: 1700028800000 }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      result = service.clock_out(shift_id: "SHIFT1")

      expect(result["outTime"]).not_to be_nil
    end
  end

  describe "#get_active_shifts" do
    it "returns only shifts without out_time" do
      stub_request(:get, "#{base_url}/shifts")
        .with(query: { limit: 100 })
        .to_return(
          status: 200,
          body: {
            "elements" => [
              { "id" => "SHIFT1", "employee" => { "id" => "EMP1" }, "inTime" => 1700000000000, "outTime" => 1700028800000 },
              { "id" => "SHIFT2", "employee" => { "id" => "EMP2" }, "inTime" => 1700000000000 }
            ]
          }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      result = service.get_active_shifts

      expect(result.size).to eq(1)
      expect(result.first["id"]).to eq("SHIFT2")
    end
  end

  describe "#get_employee_shift" do
    it "returns the active shift for an employee" do
      stub_request(:get, "#{base_url}/shifts")
        .with(query: { limit: 100 })
        .to_return(
          status: 200,
          body: {
            "elements" => [
              { "id" => "SHIFT1", "employee" => { "id" => "EMP1" }, "inTime" => 1700000000000, "outTime" => 1700028800000 },
              { "id" => "SHIFT2", "employee" => { "id" => "EMP1" }, "inTime" => 1700100000000 }
            ]
          }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      result = service.get_employee_shift(employee_id: "EMP1")

      expect(result["id"]).to eq("SHIFT2")
    end

    it "returns nil if employee has no active shift" do
      stub_request(:get, "#{base_url}/shifts")
        .with(query: { limit: 100 })
        .to_return(
          status: 200,
          body: {
            "elements" => [
              { "id" => "SHIFT1", "employee" => { "id" => "EMP1" }, "inTime" => 1700000000000, "outTime" => 1700028800000 }
            ]
          }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      result = service.get_employee_shift(employee_id: "EMP1")

      expect(result).to be_nil
    end
  end
end
