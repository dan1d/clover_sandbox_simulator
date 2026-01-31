# frozen_string_literal: true

require "spec_helper"

RSpec.describe PosSimulator::Services::Clover::CustomerService do
  before { stub_clover_credentials }

  let(:service) { described_class.new }
  let(:base_url) { "https://sandbox.dev.clover.com/v3/merchants/TEST_MERCHANT_ID" }

  let(:sample_customers) do
    [
      { "id" => "CUST1", "firstName" => "John", "lastName" => "Doe", 
        "emailAddresses" => [{ "emailAddress" => "john.doe@example.com" }] },
      { "id" => "CUST2", "firstName" => "Jane", "lastName" => "Smith",
        "phoneNumbers" => [{ "phoneNumber" => "555-1234" }] },
      { "id" => "CUST3", "firstName" => "Bob", "lastName" => "Wilson" }
    ]
  end

  describe "#get_customers" do
    it "fetches all customers" do
      stub_request(:get, "#{base_url}/customers")
        .to_return(
          status: 200,
          body: { elements: sample_customers }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      customers = service.get_customers

      expect(customers.size).to eq(3)
      expect(customers.first["id"]).to eq("CUST1")
      expect(customers.first["firstName"]).to eq("John")
    end

    it "returns empty array when no customers exist" do
      stub_request(:get, "#{base_url}/customers")
        .to_return(
          status: 200,
          body: { elements: [] }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      customers = service.get_customers

      expect(customers).to eq([])
    end

    it "returns empty array when elements key is missing" do
      stub_request(:get, "#{base_url}/customers")
        .to_return(
          status: 200,
          body: {}.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      customers = service.get_customers

      expect(customers).to eq([])
    end

    it "returns empty array when response is nil" do
      stub_request(:get, "#{base_url}/customers")
        .to_return(
          status: 200,
          body: "",
          headers: { "Content-Type" => "application/json" }
        )

      customers = service.get_customers

      expect(customers).to eq([])
    end
  end

  describe "#get_customer" do
    it "fetches a specific customer by ID" do
      stub_request(:get, "#{base_url}/customers/CUST1")
        .to_return(
          status: 200,
          body: sample_customers.first.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      customer = service.get_customer("CUST1")

      expect(customer["id"]).to eq("CUST1")
      expect(customer["firstName"]).to eq("John")
      expect(customer["lastName"]).to eq("Doe")
    end

    it "returns nil when customer not found" do
      stub_request(:get, "#{base_url}/customers/NONEXISTENT")
        .to_return(
          status: 200,
          body: "",
          headers: { "Content-Type" => "application/json" }
        )

      customer = service.get_customer("NONEXISTENT")

      expect(customer).to be_nil
    end
  end

  describe "#create_customer" do
    it "creates a customer with all fields" do
      expected_payload = {
        "firstName" => "Alice",
        "lastName" => "Johnson",
        "emailAddresses" => [{ "emailAddress" => "alice@example.com" }],
        "phoneNumbers" => [{ "phoneNumber" => "555-9999" }]
      }

      stub_request(:post, "#{base_url}/customers")
        .with(body: expected_payload.to_json)
        .to_return(
          status: 200,
          body: { id: "NEW_CUST", **expected_payload }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      customer = service.create_customer(
        first_name: "Alice",
        last_name: "Johnson",
        email: "alice@example.com",
        phone: "555-9999"
      )

      expect(customer["id"]).to eq("NEW_CUST")
      expect(customer["firstName"]).to eq("Alice")
      expect(customer["lastName"]).to eq("Johnson")
    end

    it "creates a customer with only required fields" do
      expected_payload = {
        "firstName" => "Charlie",
        "lastName" => "Brown"
      }

      stub_request(:post, "#{base_url}/customers")
        .with(body: expected_payload.to_json)
        .to_return(
          status: 200,
          body: { id: "NEW_CUST2", **expected_payload }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      customer = service.create_customer(
        first_name: "Charlie",
        last_name: "Brown"
      )

      expect(customer["id"]).to eq("NEW_CUST2")
      expect(customer["firstName"]).to eq("Charlie")
    end

    it "creates a customer with email only (no phone)" do
      expected_payload = {
        "firstName" => "Dave",
        "lastName" => "Miller",
        "emailAddresses" => [{ "emailAddress" => "dave@example.com" }]
      }

      stub_request(:post, "#{base_url}/customers")
        .with(body: expected_payload.to_json)
        .to_return(
          status: 200,
          body: { id: "NEW_CUST3", **expected_payload }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      customer = service.create_customer(
        first_name: "Dave",
        last_name: "Miller",
        email: "dave@example.com"
      )

      expect(customer["emailAddresses"]).not_to be_empty
      expect(customer["emailAddresses"].first["emailAddress"]).to eq("dave@example.com")
    end

    it "creates a customer with phone only (no email)" do
      expected_payload = {
        "firstName" => "Eve",
        "lastName" => "Davis",
        "phoneNumbers" => [{ "phoneNumber" => "555-0000" }]
      }

      stub_request(:post, "#{base_url}/customers")
        .with(body: expected_payload.to_json)
        .to_return(
          status: 200,
          body: { id: "NEW_CUST4", **expected_payload }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      customer = service.create_customer(
        first_name: "Eve",
        last_name: "Davis",
        phone: "555-0000"
      )

      expect(customer["phoneNumbers"]).not_to be_empty
      expect(customer["phoneNumbers"].first["phoneNumber"]).to eq("555-0000")
    end
  end

  describe "#ensure_customers" do
    context "when enough customers already exist" do
      it "returns existing customers without creating new ones" do
        stub_request(:get, "#{base_url}/customers")
          .to_return(
            status: 200,
            body: { elements: sample_customers }.to_json,
            headers: { "Content-Type" => "application/json" }
          )

        # Should not make any POST requests
        result = service.ensure_customers(count: 3)

        expect(result.size).to eq(3)
        expect(WebMock).not_to have_requested(:post, "#{base_url}/customers")
      end

      it "returns existing customers when more than count exist" do
        stub_request(:get, "#{base_url}/customers")
          .to_return(
            status: 200,
            body: { elements: sample_customers }.to_json,
            headers: { "Content-Type" => "application/json" }
          )

        result = service.ensure_customers(count: 2)

        expect(result.size).to eq(3)
        expect(WebMock).not_to have_requested(:post, "#{base_url}/customers")
      end
    end

    context "when not enough customers exist" do
      before do
        # Allow Faker to generate predictable names
        allow(Faker::Name).to receive(:first_name).and_return("Test")
        allow(Faker::Name).to receive(:last_name).and_return("User")
        allow(Faker::PhoneNumber).to receive(:cell_phone).and_return("555-1111")
      end

      it "creates new customers to reach the desired count" do
        existing_customers = [sample_customers.first]

        stub_request(:get, "#{base_url}/customers")
          .to_return(
            status: 200,
            body: { elements: existing_customers }.to_json,
            headers: { "Content-Type" => "application/json" }
          )

        stub_request(:post, "#{base_url}/customers")
          .to_return(
            status: 200,
            body: { id: "NEW_CUST", firstName: "Test", lastName: "User" }.to_json,
            headers: { "Content-Type" => "application/json" }
          )

        result = service.ensure_customers(count: 3)

        expect(result.size).to eq(3)
        expect(WebMock).to have_requested(:post, "#{base_url}/customers").times(2)
      end

      it "creates customers when none exist" do
        stub_request(:get, "#{base_url}/customers")
          .to_return(
            status: 200,
            body: { elements: [] }.to_json,
            headers: { "Content-Type" => "application/json" }
          )

        stub_request(:post, "#{base_url}/customers")
          .to_return(
            status: 200,
            body: { id: "NEW_CUST", firstName: "Test", lastName: "User" }.to_json,
            headers: { "Content-Type" => "application/json" }
          )

        result = service.ensure_customers(count: 5)

        expect(result.size).to eq(5)
        expect(WebMock).to have_requested(:post, "#{base_url}/customers").times(5)
      end

      it "uses default count of 10 when not specified" do
        stub_request(:get, "#{base_url}/customers")
          .to_return(
            status: 200,
            body: { elements: [] }.to_json,
            headers: { "Content-Type" => "application/json" }
          )

        stub_request(:post, "#{base_url}/customers")
          .to_return(
            status: 200,
            body: { id: "NEW_CUST", firstName: "Test", lastName: "User" }.to_json,
            headers: { "Content-Type" => "application/json" }
          )

        result = service.ensure_customers

        expect(result.size).to eq(10)
        expect(WebMock).to have_requested(:post, "#{base_url}/customers").times(10)
      end

      it "generates sanitized email addresses" do
        allow(Faker::Name).to receive(:first_name).and_return("Mary-Jane")
        allow(Faker::Name).to receive(:last_name).and_return("O'Connor")

        stub_request(:get, "#{base_url}/customers")
          .to_return(
            status: 200,
            body: { elements: [] }.to_json,
            headers: { "Content-Type" => "application/json" }
          )

        # Expect sanitized email: maryjane.oconnor@example.com
        stub_request(:post, "#{base_url}/customers")
          .with(body: hash_including(
            "emailAddresses" => [{ "emailAddress" => "maryjane.oconnor@example.com" }]
          ))
          .to_return(
            status: 200,
            body: { id: "NEW_CUST" }.to_json,
            headers: { "Content-Type" => "application/json" }
          )

        service.ensure_customers(count: 1)

        expect(WebMock).to have_requested(:post, "#{base_url}/customers")
          .with(body: hash_including("emailAddresses" => [{ "emailAddress" => "maryjane.oconnor@example.com" }]))
      end

      it "handles nil response from create_customer gracefully" do
        stub_request(:get, "#{base_url}/customers")
          .to_return(
            status: 200,
            body: { elements: [] }.to_json,
            headers: { "Content-Type" => "application/json" }
          )

        # First creation succeeds, second returns nil/empty
        stub_request(:post, "#{base_url}/customers")
          .to_return(
            { status: 200, body: { id: "NEW_CUST1" }.to_json, headers: { "Content-Type" => "application/json" } },
            { status: 200, body: "", headers: { "Content-Type" => "application/json" } }
          )

        result = service.ensure_customers(count: 2)

        # Only the successful creation should be in the result
        expect(result.size).to eq(1)
      end
    end
  end

  describe "#random_customer" do
    context "when random returns >= 0.3 (70% chance - return customer)" do
      before do
        allow(service).to receive(:rand).and_return(0.5)
      end

      it "returns a random customer from the list" do
        stub_request(:get, "#{base_url}/customers")
          .to_return(
            status: 200,
            body: { elements: sample_customers }.to_json,
            headers: { "Content-Type" => "application/json" }
          )

        customer = service.random_customer

        expect(sample_customers.map { |c| c["id"] }).to include(customer["id"])
      end

      it "returns nil when no customers exist" do
        stub_request(:get, "#{base_url}/customers")
          .to_return(
            status: 200,
            body: { elements: [] }.to_json,
            headers: { "Content-Type" => "application/json" }
          )

        customer = service.random_customer

        expect(customer).to be_nil
      end
    end

    context "when random returns < 0.3 (30% chance - anonymous order)" do
      before do
        allow(service).to receive(:rand).and_return(0.2)
      end

      it "returns nil for anonymous order" do
        # Should not even make a request to get customers
        customer = service.random_customer

        expect(customer).to be_nil
        expect(WebMock).not_to have_requested(:get, "#{base_url}/customers")
      end
    end

    context "edge cases for random values" do
      it "returns nil when random is exactly 0.0" do
        allow(service).to receive(:rand).and_return(0.0)

        customer = service.random_customer

        expect(customer).to be_nil
      end

      it "returns nil when random is 0.29" do
        allow(service).to receive(:rand).and_return(0.29)

        customer = service.random_customer

        expect(customer).to be_nil
      end

      it "returns a customer when random is exactly 0.3" do
        allow(service).to receive(:rand).and_return(0.3)

        stub_request(:get, "#{base_url}/customers")
          .to_return(
            status: 200,
            body: { elements: sample_customers }.to_json,
            headers: { "Content-Type" => "application/json" }
          )

        customer = service.random_customer

        expect(customer).not_to be_nil
      end

      it "returns a customer when random is 1.0" do
        allow(service).to receive(:rand).and_return(1.0)

        stub_request(:get, "#{base_url}/customers")
          .to_return(
            status: 200,
            body: { elements: sample_customers }.to_json,
            headers: { "Content-Type" => "application/json" }
          )

        customer = service.random_customer

        expect(customer).not_to be_nil
      end
    end
  end

  describe "#delete_customer" do
    it "deletes a customer by ID" do
      stub_request(:delete, "#{base_url}/customers/CUST1")
        .to_return(
          status: 200,
          body: "",
          headers: { "Content-Type" => "application/json" }
        )

      result = service.delete_customer("CUST1")

      expect(WebMock).to have_requested(:delete, "#{base_url}/customers/CUST1")
      expect(result).to be_nil # DELETE typically returns empty body
    end

    it "handles delete with response body" do
      stub_request(:delete, "#{base_url}/customers/CUST2")
        .to_return(
          status: 200,
          body: { deleted: true }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      result = service.delete_customer("CUST2")

      expect(result["deleted"]).to be true
    end
  end

  describe "error handling" do
    it "raises ApiError on HTTP 404" do
      stub_request(:get, "#{base_url}/customers/INVALID")
        .to_return(
          status: 404,
          body: { message: "Customer not found" }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      expect {
        service.get_customer("INVALID")
      }.to raise_error(PosSimulator::ApiError, /404/)
    end

    it "raises ApiError on HTTP 401" do
      stub_request(:get, "#{base_url}/customers")
        .to_return(
          status: 401,
          body: { message: "Unauthorized" }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      expect {
        service.get_customers
      }.to raise_error(PosSimulator::ApiError, /401/)
    end

    it "raises ApiError on HTTP 500" do
      stub_request(:post, "#{base_url}/customers")
        .to_return(
          status: 500,
          body: { message: "Internal server error" }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      expect {
        service.create_customer(first_name: "Test", last_name: "User")
      }.to raise_error(PosSimulator::ApiError, /500/)
    end
  end
end
