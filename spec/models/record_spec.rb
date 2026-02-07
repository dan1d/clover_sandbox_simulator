# frozen_string_literal: true

require "spec_helper"

RSpec.describe CloverSandboxSimulator::Models::Record do
  it "is an abstract class" do
    expect(described_class).to be_abstract_class
  end

  it "inherits from ActiveRecord::Base" do
    expect(described_class.superclass).to eq(ActiveRecord::Base)
  end

  it "is the base class for all simulator models" do
    model_classes = [
      CloverSandboxSimulator::Models::BusinessType,
      CloverSandboxSimulator::Models::Category,
      CloverSandboxSimulator::Models::Item,
      CloverSandboxSimulator::Models::SimulatedOrder,
      CloverSandboxSimulator::Models::SimulatedPayment,
      CloverSandboxSimulator::Models::ApiRequest,
      CloverSandboxSimulator::Models::DailySummary
    ]

    model_classes.each do |klass|
      expect(klass.superclass).to eq(described_class),
        "Expected #{klass} to inherit from #{described_class}, but it inherits from #{klass.superclass}"
    end
  end
end
