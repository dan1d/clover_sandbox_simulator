# frozen_string_literal: true

require "spec_helper"

RSpec.describe PosSimulator::Services::Clover::DiscountService do
  before { stub_clover_credentials }
  
  let(:service) { described_class.new }
  let(:base_url) { "https://sandbox.dev.clover.com/v3/merchants/TEST_MERCHANT_ID" }

  let(:sample_discounts) do
    [
      { "id" => "D1", "name" => "10% Off", "percentage" => 10, "amount" => nil },
      { "id" => "D2", "name" => "Happy Hour", "percentage" => 15, "amount" => nil },
      { "id" => "D3", "name" => "$5 Off", "percentage" => nil, "amount" => -500 },
      { "id" => "D4", "name" => "Employee Discount", "percentage" => 20, "amount" => nil }
    ]
  end

  describe "#get_discounts" do
    it "fetches all discounts" do
      stub_request(:get, "#{base_url}/discounts")
        .to_return(
          status: 200,
          body: { elements: sample_discounts }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      discounts = service.get_discounts
      
      expect(discounts).to be_an(Array)
      expect(discounts.size).to eq(4)
      expect(discounts.first["id"]).to eq("D1")
    end

    it "returns empty array when no discounts exist" do
      stub_request(:get, "#{base_url}/discounts")
        .to_return(
          status: 200,
          body: { elements: [] }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      discounts = service.get_discounts
      
      expect(discounts).to eq([])
    end

    it "handles nil elements in response" do
      stub_request(:get, "#{base_url}/discounts")
        .to_return(
          status: 200,
          body: {}.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      discounts = service.get_discounts
      
      expect(discounts).to eq([])
    end

    it "handles nil response" do
      stub_request(:get, "#{base_url}/discounts")
        .to_return(
          status: 200,
          body: "null",
          headers: { "Content-Type" => "application/json" }
        )

      discounts = service.get_discounts
      
      expect(discounts).to eq([])
    end
  end

  describe "#get_discount" do
    it "fetches a specific discount by ID" do
      discount_data = { "id" => "D1", "name" => "10% Off", "percentage" => 10 }
      
      stub_request(:get, "#{base_url}/discounts/D1")
        .to_return(
          status: 200,
          body: discount_data.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      discount = service.get_discount("D1")
      
      expect(discount["id"]).to eq("D1")
      expect(discount["name"]).to eq("10% Off")
      expect(discount["percentage"]).to eq(10)
    end

    it "raises ApiError for non-existent discount" do
      stub_request(:get, "#{base_url}/discounts/NONEXISTENT")
        .to_return(
          status: 404,
          body: { message: "Discount not found" }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      expect { service.get_discount("NONEXISTENT") }
        .to raise_error(PosSimulator::ApiError, /404.*Discount not found/)
    end
  end

  describe "#create_percentage_discount" do
    it "creates a percentage-based discount" do
      stub_request(:post, "#{base_url}/discounts")
        .with(body: hash_including(
          "name" => "Summer Sale",
          "percentage" => 20
        ))
        .to_return(
          status: 200,
          body: { id: "D_NEW", name: "Summer Sale", percentage: 20 }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      discount = service.create_percentage_discount(name: "Summer Sale", percentage: 20)
      
      expect(discount["id"]).to eq("D_NEW")
      expect(discount["name"]).to eq("Summer Sale")
      expect(discount["percentage"]).to eq(20)
    end

    it "creates discount with small percentage" do
      stub_request(:post, "#{base_url}/discounts")
        .with(body: hash_including(
          "name" => "Tiny Discount",
          "percentage" => 1
        ))
        .to_return(
          status: 200,
          body: { id: "D_SMALL", name: "Tiny Discount", percentage: 1 }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      discount = service.create_percentage_discount(name: "Tiny Discount", percentage: 1)
      
      expect(discount["percentage"]).to eq(1)
    end

    it "creates discount with 100 percent" do
      stub_request(:post, "#{base_url}/discounts")
        .with(body: hash_including(
          "name" => "Free Item",
          "percentage" => 100
        ))
        .to_return(
          status: 200,
          body: { id: "D_FREE", name: "Free Item", percentage: 100 }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      discount = service.create_percentage_discount(name: "Free Item", percentage: 100)
      
      expect(discount["percentage"]).to eq(100)
    end

    it "handles decimal percentage values" do
      stub_request(:post, "#{base_url}/discounts")
        .with(body: hash_including(
          "name" => "Decimal Discount",
          "percentage" => 12.5
        ))
        .to_return(
          status: 200,
          body: { id: "D_DEC", name: "Decimal Discount", percentage: 12.5 }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      discount = service.create_percentage_discount(name: "Decimal Discount", percentage: 12.5)
      
      expect(discount["percentage"]).to eq(12.5)
    end
  end

  describe "#create_fixed_discount" do
    it "creates a fixed amount discount with negative amount" do
      stub_request(:post, "#{base_url}/discounts")
        .with(body: hash_including(
          "name" => "$5 Off",
          "amount" => -500 # 500 cents = $5, negated
        ))
        .to_return(
          status: 200,
          body: { id: "D_FIXED", name: "$5 Off", amount: -500 }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      discount = service.create_fixed_discount(name: "$5 Off", amount: 500)
      
      expect(discount["id"]).to eq("D_FIXED")
      expect(discount["name"]).to eq("$5 Off")
      expect(discount["amount"]).to eq(-500)
    end

    it "converts positive amount to negative for Clover API" do
      stub_request(:post, "#{base_url}/discounts")
        .with(body: hash_including("amount" => -1000))
        .to_return(
          status: 200,
          body: { id: "D_FIXED", amount: -1000 }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      service.create_fixed_discount(name: "$10 Off", amount: 1000)
      
      expect(WebMock).to have_requested(:post, "#{base_url}/discounts")
        .with(body: hash_including("amount" => -1000))
    end

    it "handles already negative amount correctly" do
      stub_request(:post, "#{base_url}/discounts")
        .with(body: hash_including("amount" => -750))
        .to_return(
          status: 200,
          body: { id: "D_FIXED", amount: -750 }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      discount = service.create_fixed_discount(name: "$7.50 Off", amount: -750)
      
      expect(discount["amount"]).to eq(-750)
    end

    it "creates small fixed discount" do
      stub_request(:post, "#{base_url}/discounts")
        .with(body: hash_including(
          "name" => "$0.25 Off",
          "amount" => -25
        ))
        .to_return(
          status: 200,
          body: { id: "D_SMALL", name: "$0.25 Off", amount: -25 }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      discount = service.create_fixed_discount(name: "$0.25 Off", amount: 25)
      
      expect(discount["amount"]).to eq(-25)
    end

    it "creates large fixed discount" do
      stub_request(:post, "#{base_url}/discounts")
        .with(body: hash_including(
          "name" => "$100 Off",
          "amount" => -10000
        ))
        .to_return(
          status: 200,
          body: { id: "D_LARGE", name: "$100 Off", amount: -10000 }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      discount = service.create_fixed_discount(name: "$100 Off", amount: 10000)
      
      expect(discount["amount"]).to eq(-10000)
    end
  end

  describe "#delete_discount" do
    it "deletes a discount by ID" do
      stub_request(:delete, "#{base_url}/discounts/D1")
        .to_return(
          status: 200,
          body: "".to_json,
          headers: { "Content-Type" => "application/json" }
        )

      result = service.delete_discount("D1")
      
      expect(WebMock).to have_requested(:delete, "#{base_url}/discounts/D1")
    end

    it "raises ApiError for deletion of non-existent discount" do
      stub_request(:delete, "#{base_url}/discounts/NONEXISTENT")
        .to_return(
          status: 404,
          body: { message: "Discount not found" }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      expect { service.delete_discount("NONEXISTENT") }
        .to raise_error(PosSimulator::ApiError, /404.*Discount not found/)
    end

    it "handles deletion with special characters in ID" do
      stub_request(:delete, "#{base_url}/discounts/D-123_ABC")
        .to_return(
          status: 200,
          body: "".to_json,
          headers: { "Content-Type" => "application/json" }
        )

      service.delete_discount("D-123_ABC")
      
      expect(WebMock).to have_requested(:delete, "#{base_url}/discounts/D-123_ABC")
    end
  end

  describe "#random_discount" do
    before do
      stub_request(:get, "#{base_url}/discounts")
        .to_return(
          status: 200,
          body: { elements: sample_discounts }.to_json,
          headers: { "Content-Type" => "application/json" }
        )
    end

    it "returns nil approximately 70% of the time" do
      allow_any_instance_of(Kernel).to receive(:rand).and_return(0.5)
      
      result = service.random_discount
      
      expect(result).to be_nil
    end

    it "returns a discount when rand is >= 0.7" do
      allow_any_instance_of(Kernel).to receive(:rand).and_return(0.8)
      
      result = service.random_discount
      
      expect(result).not_to be_nil
      expect(sample_discounts.map { |d| d["id"] }).to include(result["id"])
    end

    it "returns nil when rand is exactly 0.69" do
      allow_any_instance_of(Kernel).to receive(:rand).and_return(0.69)
      
      result = service.random_discount
      
      expect(result).to be_nil
    end

    it "returns a discount when rand is exactly 0.7" do
      allow_any_instance_of(Kernel).to receive(:rand).and_return(0.7)
      
      result = service.random_discount
      
      expect(result).not_to be_nil
    end

    it "returns nil when no discounts exist and rand triggers discount" do
      stub_request(:get, "#{base_url}/discounts")
        .to_return(
          status: 200,
          body: { elements: [] }.to_json,
          headers: { "Content-Type" => "application/json" }
        )
      
      allow_any_instance_of(Kernel).to receive(:rand).and_return(0.9)
      
      result = service.random_discount
      
      expect(result).to be_nil
    end

    context "probability distribution" do
      it "follows 70% nil / 30% discount probability" do
        nil_count = 0
        discount_count = 0
        iterations = 1000

        iterations.times do
          # Reset stubs for each iteration
          WebMock.reset!
          stub_request(:get, "#{base_url}/discounts")
            .to_return(
              status: 200,
              body: { elements: sample_discounts }.to_json,
              headers: { "Content-Type" => "application/json" }
            )

          result = service.random_discount
          if result.nil?
            nil_count += 1
          else
            discount_count += 1
          end
        end

        # Allow for statistical variance (expect ~65-75% nil)
        nil_percentage = (nil_count.to_f / iterations) * 100
        expect(nil_percentage).to be_within(7).of(70)
      end
    end
  end

  describe "API error handling" do
    it "raises ApiError for 401 unauthorized response" do
      stub_request(:get, "#{base_url}/discounts")
        .to_return(
          status: 401,
          body: { message: "Unauthorized" }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      expect { service.get_discounts }
        .to raise_error(PosSimulator::ApiError, /401.*Unauthorized/)
    end

    it "raises ApiError for 500 internal server error" do
      stub_request(:get, "#{base_url}/discounts")
        .to_return(
          status: 500,
          body: { message: "Internal Server Error" }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      expect { service.get_discounts }
        .to raise_error(PosSimulator::ApiError, /500.*Internal Server Error/)
    end

    it "raises error on network timeout" do
      stub_request(:get, "#{base_url}/discounts")
        .to_timeout

      expect { service.get_discounts }.to raise_error(StandardError)
    end

    it "raises ApiError for malformed JSON response" do
      stub_request(:get, "#{base_url}/discounts")
        .to_return(
          status: 200,
          body: "not valid json",
          headers: { "Content-Type" => "application/json" }
        )

      expect { service.get_discounts }
        .to raise_error(PosSimulator::ApiError, /Invalid JSON response/)
    end
  end

  describe "request format" do
    it "sends correct headers for GET request" do
      stub_request(:get, "#{base_url}/discounts")
        .to_return(
          status: 200,
          body: { elements: [] }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      service.get_discounts
      
      expect(WebMock).to have_requested(:get, "#{base_url}/discounts")
    end

    it "sends correct headers for POST request" do
      stub_request(:post, "#{base_url}/discounts")
        .to_return(
          status: 200,
          body: { id: "D_NEW" }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      service.create_percentage_discount(name: "Test", percentage: 10)
      
      expect(WebMock).to have_requested(:post, "#{base_url}/discounts")
    end

    it "sends correct headers for DELETE request" do
      stub_request(:delete, "#{base_url}/discounts/D1")
        .to_return(
          status: 200,
          body: "".to_json,
          headers: { "Content-Type" => "application/json" }
        )

      service.delete_discount("D1")
      
      expect(WebMock).to have_requested(:delete, "#{base_url}/discounts/D1")
    end
  end

  describe "discount data integrity" do
    it "preserves all discount attributes from response" do
      full_discount = {
        "id" => "D_FULL",
        "name" => "Full Discount",
        "percentage" => 15,
        "amount" => nil,
        "enabled" => true,
        "merchantRef" => { "id" => "MERCHANT1" },
        "createdTime" => 1609459200000,
        "modifiedTime" => 1609459200000
      }
      
      stub_request(:get, "#{base_url}/discounts/D_FULL")
        .to_return(
          status: 200,
          body: full_discount.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      discount = service.get_discount("D_FULL")
      
      expect(discount["id"]).to eq("D_FULL")
      expect(discount["name"]).to eq("Full Discount")
      expect(discount["percentage"]).to eq(15)
      expect(discount["enabled"]).to eq(true)
      expect(discount["createdTime"]).to eq(1609459200000)
    end
  end
end
