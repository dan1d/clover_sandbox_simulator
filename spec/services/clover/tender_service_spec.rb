# frozen_string_literal: true

require "spec_helper"

RSpec.describe CloverSandboxSimulator::Services::Clover::TenderService do
  before { stub_clover_credentials }

  let(:service) { described_class.new }
  let(:base_url) { "https://sandbox.dev.clover.com/v3/merchants/TEST_MERCHANT_ID" }

  let(:all_tenders) do
    [
      { "id" => "T1", "label" => "Cash", "labelKey" => "com.clover.tender.cash", "enabled" => true },
      { "id" => "T2", "label" => "Credit Card", "labelKey" => "com.clover.tender.credit_card", "enabled" => true },
      { "id" => "T3", "label" => "Debit Card", "labelKey" => "com.clover.tender.debit_card", "enabled" => true },
      { "id" => "T4", "label" => "Gift Card", "labelKey" => "com.clover.tender.external_gift_card", "enabled" => true },
      { "id" => "T5", "label" => "Check", "labelKey" => "com.clover.tender.check", "enabled" => true },
      { "id" => "T6", "label" => "Disabled", "labelKey" => "com.clover.tender.disabled", "enabled" => false }
    ]
  end

  describe "#get_tenders" do
    it "fetches only enabled tenders" do
      stub_request(:get, "#{base_url}/tenders")
        .to_return(
          status: 200,
          body: { elements: all_tenders }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      tenders = service.get_tenders

      expect(tenders.size).to eq(5) # Excludes disabled tender
      expect(tenders.all? { |t| t["enabled"] }).to be true
    end
  end

  describe "#get_safe_tenders" do
    it "excludes credit and debit cards" do
      stub_request(:get, "#{base_url}/tenders")
        .to_return(
          status: 200,
          body: { elements: all_tenders }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      safe_tenders = service.get_safe_tenders

      expect(safe_tenders.size).to eq(3) # Cash, Gift Card, Check
      expect(safe_tenders.map { |t| t["label"] }).to contain_exactly("Cash", "Gift Card", "Check")
    end

    it "is idempotent - returns same result on multiple calls" do
      stub_request(:get, "#{base_url}/tenders")
        .to_return(
          status: 200,
          body: { elements: all_tenders }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      first_call = service.get_safe_tenders
      second_call = service.get_safe_tenders

      expect(first_call.map { |t| t["id"] }).to eq(second_call.map { |t| t["id"] })
    end
  end

  describe "#find_tender_by_label" do
    it "finds tender by label (case insensitive)" do
      stub_request(:get, "#{base_url}/tenders")
        .to_return(
          status: 200,
          body: { elements: all_tenders }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      tender = service.find_tender_by_label("CASH")

      expect(tender["id"]).to eq("T1")
    end

    it "returns nil when tender not found" do
      stub_request(:get, "#{base_url}/tenders")
        .to_return(
          status: 200,
          body: { elements: all_tenders }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      tender = service.find_tender_by_label("Bitcoin")

      expect(tender).to be_nil
    end
  end

  describe "#card_tender?" do
    it "identifies credit card by labelKey" do
      tender = { "label" => "Visa", "labelKey" => "com.clover.tender.credit_card", "enabled" => true }
      expect(service.card_tender?(tender)).to be true
    end

    it "identifies debit card by labelKey" do
      tender = { "label" => "Debit", "labelKey" => "com.clover.tender.debit_card", "enabled" => true }
      expect(service.card_tender?(tender)).to be true
    end

    it "identifies credit card by label fallback" do
      tender = { "label" => "Credit Card", "labelKey" => "com.custom.tender", "enabled" => true }
      expect(service.card_tender?(tender)).to be true
    end

    it "identifies debit card by label fallback" do
      tender = { "label" => "Debit Card", "labelKey" => "com.custom.tender", "enabled" => true }
      expect(service.card_tender?(tender)).to be true
    end

    it "does not flag cash as card tender" do
      tender = { "label" => "Cash", "labelKey" => "com.clover.tender.cash", "enabled" => true }
      expect(service.card_tender?(tender)).to be false
    end

    it "does not flag gift card as card tender" do
      tender = { "label" => "Gift Card", "labelKey" => "com.clover.tender.external_gift_card", "enabled" => true }
      expect(service.card_tender?(tender)).to be false
    end

    it "does not flag check as card tender" do
      tender = { "label" => "Check", "labelKey" => "com.clover.tender.check", "enabled" => true }
      expect(service.card_tender?(tender)).to be false
    end
  end

  describe "#get_all_payment_tenders" do
    before do
      stub_request(:get, "#{base_url}/tenders")
        .to_return(
          status: 200,
          body: { elements: all_tenders }.to_json,
          headers: { "Content-Type" => "application/json" }
        )
    end

    context "when ecommerce is enabled" do
      before do
        allow(service.send(:config)).to receive(:ecommerce_enabled?).and_return(true)
      end

      it "includes card tenders" do
        tenders = service.get_all_payment_tenders
        labels = tenders.map { |t| t["label"] }

        expect(labels).to include("Credit Card")
        expect(labels).to include("Debit Card")
        expect(tenders.size).to eq(5) # All enabled tenders
      end
    end

    context "when ecommerce is not enabled" do
      before do
        allow(service.send(:config)).to receive(:ecommerce_enabled?).and_return(false)
      end

      it "excludes card tenders" do
        tenders = service.get_all_payment_tenders
        labels = tenders.map { |t| t["label"] }

        expect(labels).not_to include("Credit Card")
        expect(labels).not_to include("Debit Card")
        expect(tenders.size).to eq(3) # Cash, Gift Card, Check
      end
    end
  end

  describe "#select_split_tenders" do
    before do
      stub_request(:get, "#{base_url}/tenders")
        .to_return(
          status: 200,
          body: { elements: all_tenders }.to_json,
          headers: { "Content-Type" => "application/json" }
        )
    end

    it "returns array of tenders with percentages" do
      splits = service.select_split_tenders(num_splits: 2)

      expect(splits).to be_an(Array)
      expect(splits.size).to eq(2)
      expect(splits.first).to have_key(:tender)
      expect(splits.first).to have_key(:percentage)
    end

    it "percentages sum to approximately 100" do
      splits = service.select_split_tenders(num_splits: 3)

      total = splits.sum { |s| s[:percentage] }
      expect(total).to be >= 100 # May be slightly over due to minimum 5% rule
    end
  end
end
