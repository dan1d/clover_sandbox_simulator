# frozen_string_literal: true

require "spec_helper"

RSpec.describe PosSimulator::Services::Clover::OrderService do
  before { stub_clover_credentials }
  
  let(:service) { described_class.new }
  let(:base_url) { "https://sandbox.dev.clover.com/v3/merchants/TEST_MERCHANT_ID" }

  describe "#create_order" do
    it "creates an order shell" do
      stub_request(:post, "#{base_url}/orders")
        .with(body: hash_including("employee" => { "id" => "EMP1" }))
        .to_return(
          status: 200,
          body: { id: "ORDER123" }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      order = service.create_order(employee_id: "EMP1")
      
      expect(order["id"]).to eq("ORDER123")
    end

    it "adds customer to order if provided" do
      stub_request(:post, "#{base_url}/orders")
        .to_return(
          status: 200,
          body: { id: "ORDER123" }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      stub_request(:post, "#{base_url}/orders/ORDER123")
        .with(body: hash_including("customers"))
        .to_return(
          status: 200,
          body: { id: "ORDER123" }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      order = service.create_order(employee_id: "EMP1", customer_id: "CUST1")
      
      expect(order["id"]).to eq("ORDER123")
    end
  end

  describe "#add_line_item" do
    it "adds a line item to an order" do
      stub_request(:post, "#{base_url}/orders/ORDER123/line_items")
        .with(body: hash_including(
          "item" => { "id" => "ITEM1" },
          "quantity" => 2
        ))
        .to_return(
          status: 200,
          body: { id: "LI1", quantity: 2 }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      line_item = service.add_line_item("ORDER123", item_id: "ITEM1", quantity: 2)
      
      expect(line_item["id"]).to eq("LI1")
    end

    it "includes note if provided" do
      stub_request(:post, "#{base_url}/orders/ORDER123/line_items")
        .with(body: hash_including("note" => "No onions"))
        .to_return(
          status: 200,
          body: { id: "LI1", note: "No onions" }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      line_item = service.add_line_item("ORDER123", item_id: "ITEM1", note: "No onions")
      
      expect(line_item["note"]).to eq("No onions")
    end
  end

  describe "#set_dining_option" do
    it "sets valid dining option" do
      stub_request(:post, "#{base_url}/orders/ORDER123")
        .with(body: { diningOption: "TO_GO" }.to_json)
        .to_return(
          status: 200,
          body: { id: "ORDER123", diningOption: "TO_GO" }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      result = service.set_dining_option("ORDER123", "TO_GO")
      
      expect(result["diningOption"]).to eq("TO_GO")
    end

    it "raises error for invalid dining option" do
      expect {
        service.set_dining_option("ORDER123", "INVALID")
      }.to raise_error(ArgumentError, /Invalid dining option/)
    end
  end

  describe "#calculate_total" do
    it "calculates total from line items" do
      order_response = {
        "id" => "ORDER123",
        "lineItems" => {
          "elements" => [
            { "id" => "LI1", "price" => 1299, "quantity" => 2 },
            { "id" => "LI2", "price" => 599, "quantity" => 1 }
          ]
        }
      }

      stub_request(:get, "#{base_url}/orders/ORDER123")
        .with(query: { expand: "lineItems,discounts,payments,customers" })
        .to_return(
          status: 200,
          body: order_response.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      total = service.calculate_total("ORDER123")
      
      # (1299 * 2) + (599 * 1) = 3197
      expect(total).to eq(3197)
    end

    it "subtracts discounts from total" do
      order_response = {
        "id" => "ORDER123",
        "lineItems" => {
          "elements" => [
            { "id" => "LI1", "price" => 1000, "quantity" => 1 }
          ]
        },
        "discounts" => {
          "elements" => [
            { "id" => "D1", "amount" => -100 } # Fixed $1 discount
          ]
        }
      }

      stub_request(:get, "#{base_url}/orders/ORDER123")
        .with(query: { expand: "lineItems,discounts,payments,customers" })
        .to_return(
          status: 200,
          body: order_response.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      total = service.calculate_total("ORDER123")
      
      expect(total).to eq(900) # 1000 - 100
    end
  end
end
