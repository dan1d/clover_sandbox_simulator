# frozen_string_literal: true

require "spec_helper"

RSpec.describe PosSimulator::Configuration do
  describe "#validate!" do
    it "raises error when merchant_id is missing" do
      config = described_class.allocate
      config.instance_variable_set(:@merchant_id, nil)
      config.instance_variable_set(:@api_token, "TOKEN")
      
      expect { config.validate! }.to raise_error(PosSimulator::ConfigurationError, /CLOVER_MERCHANT_ID/)
    end

    it "raises error when merchant_id is empty" do
      config = described_class.allocate
      config.instance_variable_set(:@merchant_id, "")
      config.instance_variable_set(:@api_token, "TOKEN")
      
      expect { config.validate! }.to raise_error(PosSimulator::ConfigurationError, /CLOVER_MERCHANT_ID/)
    end

    it "raises error when api_token is missing" do
      config = described_class.allocate
      config.instance_variable_set(:@merchant_id, "MERCHANT")
      config.instance_variable_set(:@api_token, nil)
      
      expect { config.validate! }.to raise_error(PosSimulator::ConfigurationError, /CLOVER_API_TOKEN/)
    end

    it "returns true when valid" do
      config = create_test_config
      
      expect(config.validate!).to be true
    end
  end

  describe "#logger" do
    it "returns a configured logger" do
      config = create_test_config
      
      expect(config.logger).to be_a(Logger)
    end

    it "caches the logger instance" do
      config = create_test_config
      
      logger1 = config.logger
      logger2 = config.logger
      
      expect(logger1).to be(logger2)
    end
  end

  describe "attribute accessors" do
    it "exposes all configuration values" do
      config = create_test_config
      
      expect(config.merchant_id).to eq("TEST_MERCHANT_ID")
      expect(config.api_token).to eq("TEST_API_TOKEN")
      expect(config.environment).to eq("https://sandbox.dev.clover.com/")
      expect(config.tax_rate).to eq(8.25)
      expect(config.business_type).to eq(:restaurant)
    end
  end
end
