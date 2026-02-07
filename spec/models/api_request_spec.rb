# frozen_string_literal: true

require "spec_helper"

RSpec.describe CloverSandboxSimulator::Models::ApiRequest, :db do
  describe "validations" do
    it "requires http_method" do
      req = build(:api_request, http_method: nil)
      expect(req).not_to be_valid
      expect(req.errors[:http_method]).to include("can't be blank")
    end

    it "requires url" do
      req = build(:api_request, url: nil)
      expect(req).not_to be_valid
      expect(req.errors[:url]).to include("can't be blank")
    end
  end

  describe "scopes" do
    before do
      create(:api_request, :get, url: "https://sandbox.dev.clover.com/v3/merchants/M1/orders", resource_type: "Order")
      create(:api_request, :post, :error, url: "https://sandbox.dev.clover.com/v3/merchants/M1/orders", resource_type: "Order")
      create(:api_request, :get, url: "https://sandbox.dev.clover.com/v3/merchants/M2/items", resource_type: "Item")
      create(:api_request, :delete, url: "https://sandbox.dev.clover.com/v3/merchants/M3", resource_type: "Merchant")
      create(:api_request, :put, url: "https://sandbox.dev.clover.com/v3/merchants/M1/items/I1", resource_type: "Item", resource_id: "I1")
    end

    describe "status scopes" do
      it ".errors returns failed requests" do
        expect(described_class.errors.count).to eq(1)
      end

      it ".successful returns OK requests" do
        expect(described_class.successful.count).to eq(4)
      end
    end

    describe "HTTP method scopes" do
      it ".gets returns GET requests" do
        expect(described_class.gets.count).to eq(2)
      end

      it ".posts returns POST requests" do
        expect(described_class.posts.count).to eq(1)
      end

      it ".puts returns PUT requests" do
        expect(described_class.puts.count).to eq(1)
      end

      it ".deletes returns DELETE requests" do
        expect(described_class.deletes.count).to eq(1)
      end
    end

    describe "resource scopes" do
      it ".for_resource filters by type" do
        expect(described_class.for_resource("Order").count).to eq(2)
      end

      it ".for_resource_id filters by type and id" do
        expect(described_class.for_resource_id("Item", "I1").count).to eq(1)
      end
    end

    describe "merchant scope" do
      it ".for_merchant filters by merchant ID in URL" do
        expect(described_class.for_merchant("M1").count).to eq(3)
        expect(described_class.for_merchant("M2").count).to eq(1)
      end

      it ".for_merchant matches merchant ID at end of URL (no trailing slash)" do
        expect(described_class.for_merchant("M3").count).to eq(1)
      end

      it ".for_merchant sanitizes LIKE metacharacters" do
        expect(described_class.for_merchant("M%").count).to eq(0)
      end
    end

    describe "time scopes" do
      it ".today returns requests created today" do
        expect(described_class.today.count).to eq(5)
      end

      it ".recent returns requests within N minutes" do
        expect(described_class.recent(60).count).to eq(5)
        expect(described_class.recent(0).count).to eq(0)
      end
    end

    describe "performance scopes" do
      it ".slow filters by duration threshold" do
        create(:api_request, :slow)
        create(:api_request, :fast)
        # 5 base (150ms) + 1 slow (2500ms) = 6 exceed default 1000ms threshold? No — only slow exceeds 1000ms
        expect(described_class.slow.count).to eq(1)
        # All 7 requests exceed 20ms (fast=25ms > 20ms)
        expect(described_class.slow(20).count).to eq(7)
      end
    end
  end

  describe "payload storage" do
    it "stores and retrieves request_payload" do
      req = create(:api_request, :post)
      req.reload
      expect(req.request_payload).to include("name" => "New Item")
    end

    it "stores and retrieves response_payload" do
      req = create(:api_request, :error)
      req.reload
      expect(req.response_payload).to include("message" => "Internal Server Error")
    end
  end

  describe "#error?" do
    it "returns false for successful responses" do
      expect(build(:api_request, response_status: 200).error?).to be false
    end

    it "returns true for server errors" do
      expect(build(:api_request, response_status: 500).error?).to be true
    end

    it "returns true when error_message is present" do
      expect(build(:api_request, error_message: "timeout").error?).to be true
    end

    it "returns true for 404 responses" do
      expect(build(:api_request, :not_found).error?).to be true
    end
  end
end
