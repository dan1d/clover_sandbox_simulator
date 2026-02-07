# frozen_string_literal: true

require "spec_helper"

RSpec.describe CloverSandboxSimulator::Models::SimulatedPayment, :db do
  describe "validations" do
    it "requires tender_name" do
      payment = build(:simulated_payment, tender_name: nil)
      expect(payment).not_to be_valid
      expect(payment.errors[:tender_name]).to include("can't be blank")
    end

    it "requires status" do
      payment = build(:simulated_payment, status: nil)
      expect(payment).not_to be_valid
      expect(payment.errors[:status]).to include("can't be blank")
    end

    it "requires amount to be a non-negative integer" do
      expect(build(:simulated_payment, amount: 1500)).to be_valid
      expect(build(:simulated_payment, amount: 0)).to be_valid
      expect(build(:simulated_payment, amount: -100)).not_to be_valid
    end
  end

  describe "associations" do
    it "belongs_to simulated_order" do
      payment = create(:simulated_payment, :success)
      expect(payment.simulated_order).to be_a(CloverSandboxSimulator::Models::SimulatedOrder)
    end
  end

  describe "payment_type" do
    it "records cash payment type" do
      payment = build(:simulated_payment, :cash_tender)
      expect(payment.tender_name).to eq("Cash")
      expect(payment.payment_type).to eq("cash")
    end

    it "records credit payment type" do
      payment = build(:simulated_payment, :credit_tender)
      expect(payment.tender_name).to eq("Credit Card")
      expect(payment.payment_type).to eq("credit")
    end

    it "records debit payment type" do
      payment = build(:simulated_payment, :debit_tender)
      expect(payment.tender_name).to eq("Debit Card")
      expect(payment.payment_type).to eq("debit")
    end

    it "records gift card payment type" do
      payment = build(:simulated_payment, :gift_card_tender)
      expect(payment.tender_name).to eq("Gift Card")
      expect(payment.payment_type).to eq("gift_card")
    end
  end

  describe "scopes" do
    let!(:order) { create(:simulated_order) }

    before do
      create(:simulated_payment, :success, :cash_tender, simulated_order: order, amount: 1000)
      create(:simulated_payment, status: "pending", tender_name: "Gift Card", simulated_order: order, amount: 500)
      create(:simulated_payment, :refunded, :credit_tender, simulated_order: order, amount: 2000)
    end

    it ".successful returns paid payments" do
      expect(described_class.successful.count).to eq(1)
    end

    it ".pending returns pending payments" do
      expect(described_class.pending.count).to eq(1)
    end

    it ".refunded returns refunded payments" do
      expect(described_class.refunded.count).to eq(1)
    end

    it ".cash returns cash payments" do
      expect(described_class.cash.count).to eq(1)
    end

    it ".by_tender filters by tender name" do
      expect(described_class.by_tender("Gift Card").count).to eq(1)
    end
  end

  describe "#amount_dollars" do
    it "converts cents to dollars" do
      payment = build(:simulated_payment, amount: 1599)
      expect(payment.amount_dollars).to eq(15.99)
    end

    it "handles nil" do
      payment = build(:simulated_payment, amount: nil)
      expect(payment.amount_dollars).to eq(0.0)
    end
  end
end
