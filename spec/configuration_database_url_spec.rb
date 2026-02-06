# frozen_string_literal: true

require "spec_helper"

RSpec.describe CloverSandboxSimulator::Configuration do
  describe ".database_url_from_file" do
    let(:merchants_file) { described_class::MERCHANTS_FILE }

    context "when .env.json has the new object format" do
      before do
        allow(File).to receive(:exist?).with(merchants_file).and_return(true)
        allow(File).to receive(:read).with(merchants_file).and_return(
          '{"DATABASE_URL": "postgres://localhost:5432/clover_simulator_development", "merchants": []}'
        )
      end

      it "returns the DATABASE_URL" do
        expect(described_class.database_url_from_file).to eq("postgres://localhost:5432/clover_simulator_development")
      end
    end

    context "when .env.json has the legacy array format" do
      before do
        allow(File).to receive(:exist?).with(merchants_file).and_return(true)
        allow(File).to receive(:read).with(merchants_file).and_return(
          '[{"CLOVER_MERCHANT_ID": "TEST123"}]'
        )
      end

      it "returns nil" do
        expect(described_class.database_url_from_file).to be_nil
      end
    end

    context "when .env.json does not exist" do
      before do
        allow(File).to receive(:exist?).with(merchants_file).and_return(false)
      end

      it "returns nil" do
        expect(described_class.database_url_from_file).to be_nil
      end
    end

    context "when .env.json has invalid JSON" do
      before do
        allow(File).to receive(:exist?).with(merchants_file).and_return(true)
        allow(File).to receive(:read).with(merchants_file).and_return("not valid json {{{")
      end

      it "returns nil" do
        expect(described_class.database_url_from_file).to be_nil
      end
    end

    context "when .env.json object has no DATABASE_URL key" do
      before do
        allow(File).to receive(:exist?).with(merchants_file).and_return(true)
        allow(File).to receive(:read).with(merchants_file).and_return(
          '{"merchants": [{"CLOVER_MERCHANT_ID": "TEST123"}]}'
        )
      end

      it "returns nil" do
        expect(described_class.database_url_from_file).to be_nil
      end
    end
  end

  describe "#load_merchants_file (backward compatibility)" do
    let(:config) do
      c = described_class.allocate
      c.instance_variable_set(:@log_level, Logger::ERROR)
      c
    end
    let(:merchants_file) { described_class::MERCHANTS_FILE }

    context "with new object format" do
      before do
        allow(File).to receive(:exist?).with(merchants_file).and_return(true)
        allow(File).to receive(:read).with(merchants_file).and_return(
          '{"DATABASE_URL": "postgres://localhost/test", "merchants": [{"CLOVER_MERCHANT_ID": "M1"}, {"CLOVER_MERCHANT_ID": "M2"}]}'
        )
      end

      it "returns the merchants array" do
        merchants = config.send(:load_merchants_file)
        expect(merchants).to be_an(Array)
        expect(merchants.length).to eq(2)
        expect(merchants.first["CLOVER_MERCHANT_ID"]).to eq("M1")
      end
    end

    context "with legacy array format" do
      before do
        allow(File).to receive(:exist?).with(merchants_file).and_return(true)
        allow(File).to receive(:read).with(merchants_file).and_return(
          '[{"CLOVER_MERCHANT_ID": "M1"}]'
        )
      end

      it "returns the array directly" do
        merchants = config.send(:load_merchants_file)
        expect(merchants).to be_an(Array)
        expect(merchants.length).to eq(1)
        expect(merchants.first["CLOVER_MERCHANT_ID"]).to eq("M1")
      end
    end
  end
end
