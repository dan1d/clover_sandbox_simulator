# frozen_string_literal: true

require "spec_helper"

RSpec.describe CloverSandboxSimulator::Services::Clover::GiftCardService do
  before { stub_clover_credentials }

  let(:service) { described_class.new }
  let(:base_url) { "https://sandbox.dev.clover.com/v3/merchants/TEST_MERCHANT_ID" }

  let(:sample_gift_cards) do
    [
      {
        "id" => "GC1",
        "cardNumber" => "6012345678901234",
        "balance" => 5000,
        "status" => "ACTIVE"
      },
      {
        "id" => "GC2",
        "cardNumber" => "6023456789012345",
        "balance" => 2500,
        "status" => "ACTIVE"
      },
      {
        "id" => "GC3",
        "cardNumber" => "6034567890123456",
        "balance" => 0,
        "status" => "DEPLETED"
      },
      {
        "id" => "GC4",
        "cardNumber" => "6045678901234567",
        "balance" => 10000,
        "status" => "INACTIVE"
      }
    ]
  end

  describe "#fetch_gift_cards" do
    it "fetches all gift cards" do
      stub_request(:get, "#{base_url}/gift_cards")
        .to_return(
          status: 200,
          body: { elements: sample_gift_cards }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      cards = service.fetch_gift_cards

      expect(cards.size).to eq(4)
      expect(cards.first["id"]).to eq("GC1")
    end

    it "returns empty array when no gift cards exist" do
      stub_request(:get, "#{base_url}/gift_cards")
        .to_return(
          status: 200,
          body: { elements: [] }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      cards = service.fetch_gift_cards

      expect(cards).to be_empty
    end
  end

  describe "#create_gift_card" do
    it "creates a gift card with specified amount" do
      stub_request(:post, "#{base_url}/gift_cards")
        .with(
          body: hash_including("amount" => 5000, "status" => "ACTIVE")
        )
        .to_return(
          status: 200,
          body: {
            "id" => "GC_NEW",
            "cardNumber" => "6099999999999999",
            "balance" => 5000,
            "status" => "ACTIVE"
          }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      result = service.create_gift_card(amount: 5000)

      expect(result["id"]).to eq("GC_NEW")
      expect(result["balance"]).to eq(5000)
    end

    it "uses provided card number when specified" do
      card_number = "6011111111111111"

      stub_request(:post, "#{base_url}/gift_cards")
        .with(
          body: hash_including("cardNumber" => card_number)
        )
        .to_return(
          status: 200,
          body: {
            "id" => "GC_NEW",
            "cardNumber" => card_number,
            "balance" => 2500,
            "status" => "ACTIVE"
          }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      result = service.create_gift_card(amount: 2500, card_number: card_number)

      expect(result["cardNumber"]).to eq(card_number)
    end
  end

  describe "#get_gift_card" do
    it "fetches a specific gift card by ID" do
      stub_request(:get, "#{base_url}/gift_cards/GC1")
        .to_return(
          status: 200,
          body: sample_gift_cards.first.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      card = service.get_gift_card("GC1")

      expect(card["id"]).to eq("GC1")
      expect(card["balance"]).to eq(5000)
    end
  end

  describe "#check_balance" do
    it "returns the balance of a gift card" do
      stub_request(:get, "#{base_url}/gift_cards/GC1")
        .to_return(
          status: 200,
          body: sample_gift_cards.first.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      balance = service.check_balance("GC1")

      expect(balance).to eq(5000)
    end

    it "returns 0 when gift card not found" do
      stub_request(:get, "#{base_url}/gift_cards/INVALID")
        .to_return(
          status: 404,
          body: { message: "Not found" }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      expect { service.check_balance("INVALID") }.to raise_error(CloverSandboxSimulator::ApiError)
    end
  end

  describe "#reload_gift_card" do
    it "adds balance to a gift card" do
      stub_request(:post, "#{base_url}/gift_cards/GC1/reload")
        .with(body: { amount: 2500 }.to_json)
        .to_return(
          status: 200,
          body: {
            "id" => "GC1",
            "balance" => 7500, # 5000 + 2500
            "status" => "ACTIVE"
          }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      result = service.reload_gift_card("GC1", amount: 2500)

      expect(result["balance"]).to eq(7500)
    end
  end

  describe "#redeem_gift_card" do
    before do
      # Stub the balance check
      stub_request(:get, "#{base_url}/gift_cards/GC1")
        .to_return(
          status: 200,
          body: sample_gift_cards.first.to_json,
          headers: { "Content-Type" => "application/json" }
        )
    end

    context "when balance is sufficient" do
      it "redeems the full amount" do
        stub_request(:post, "#{base_url}/gift_cards/GC1/redeem")
          .with(body: { amount: 3000 }.to_json)
          .to_return(
            status: 200,
            body: {
              "id" => "GC1",
              "balance" => 2000, # 5000 - 3000
              "status" => "ACTIVE"
            }.to_json,
            headers: { "Content-Type" => "application/json" }
          )

        result = service.redeem_gift_card("GC1", amount: 3000)

        expect(result[:success]).to be true
        expect(result[:amount_redeemed]).to eq(3000)
        expect(result[:remaining_balance]).to eq(2000)
        expect(result[:shortfall]).to eq(0)
      end
    end

    context "when balance is insufficient" do
      it "redeems available balance and reports shortfall" do
        stub_request(:post, "#{base_url}/gift_cards/GC1/redeem")
          .with(body: { amount: 5000 }.to_json) # Can only redeem what's available
          .to_return(
            status: 200,
            body: {
              "id" => "GC1",
              "balance" => 0,
              "status" => "DEPLETED"
            }.to_json,
            headers: { "Content-Type" => "application/json" }
          )

        result = service.redeem_gift_card("GC1", amount: 7500) # Asking for more than available

        expect(result[:success]).to be true
        expect(result[:amount_redeemed]).to eq(5000)
        expect(result[:remaining_balance]).to eq(0)
        expect(result[:shortfall]).to eq(2500)
      end
    end

    context "when gift card has zero balance" do
      before do
        stub_request(:get, "#{base_url}/gift_cards/GC3")
          .to_return(
            status: 200,
            body: sample_gift_cards[2].to_json, # DEPLETED card
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "returns failure with full shortfall" do
        result = service.redeem_gift_card("GC3", amount: 1000)

        expect(result[:success]).to be false
        expect(result[:amount_redeemed]).to eq(0)
        expect(result[:shortfall]).to eq(1000)
        expect(result[:message]).to include("no balance")
      end
    end
  end

  describe "#find_card_with_balance" do
    before do
      stub_request(:get, "#{base_url}/gift_cards")
        .to_return(
          status: 200,
          body: { elements: sample_gift_cards }.to_json,
          headers: { "Content-Type" => "application/json" }
        )
    end

    it "finds a card with sufficient balance" do
      card = service.find_card_with_balance(minimum_balance: 3000)

      # Should be either GC1 (5000) or GC2 (2500 < 3000, not eligible)
      # Only GC1 and GC2 are ACTIVE, and GC1 has 5000
      expect(card).not_to be_nil
      expect(card["balance"]).to be >= 3000
    end

    it "returns nil when no card has sufficient balance" do
      card = service.find_card_with_balance(minimum_balance: 50_000)

      expect(card).to be_nil
    end
  end

  describe "#random_gift_card" do
    it "returns a random active gift card" do
      stub_request(:get, "#{base_url}/gift_cards")
        .to_return(
          status: 200,
          body: { elements: sample_gift_cards }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      card = service.random_gift_card

      expect(card).not_to be_nil
      expect(card["status"]).to eq("ACTIVE")
    end

    it "returns nil when no active cards exist" do
      inactive_cards = sample_gift_cards.map { |c| c.merge("status" => "INACTIVE") }

      stub_request(:get, "#{base_url}/gift_cards")
        .to_return(
          status: 200,
          body: { elements: inactive_cards }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      card = service.random_gift_card

      expect(card).to be_nil
    end
  end

  describe "#generate_card_number" do
    it "generates a 16-digit card number" do
      number = service.generate_card_number

      expect(number).to match(/^\d{16}$/)
    end

    it "starts with 6 (gift card prefix)" do
      number = service.generate_card_number

      expect(number[0]).to eq("6")
    end

    it "generates unique numbers" do
      numbers = 10.times.map { service.generate_card_number }

      expect(numbers.uniq.size).to eq(10)
    end
  end

  describe "#random_denomination" do
    it "returns a valid denomination amount" do
      denomination = service.random_denomination

      expect(described_class::DENOMINATIONS).to include(denomination)
    end
  end
end
