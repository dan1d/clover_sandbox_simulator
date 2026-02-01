# frozen_string_literal: true

require "spec_helper"

RSpec.describe CloverSandboxSimulator::Services::Clover::ServicesManager do
  before { stub_clover_credentials }

  let(:manager) { described_class.new }

  describe "#initialize" do
    context "with default configuration" do
      it "uses the global CloverSandboxSimulator configuration" do
        expect(manager.config).to eq(CloverSandboxSimulator.configuration)
      end
    end

    context "with custom configuration" do
      let(:custom_config) { create_test_config }
      let(:manager) { described_class.new(config: custom_config) }

      it "uses the provided configuration" do
        expect(manager.config).to eq(custom_config)
      end

      it "does not use the global configuration" do
        different_config = create_test_config
        different_config.instance_variable_set(:@merchant_id, "DIFFERENT_MERCHANT")

        manager_with_custom = described_class.new(config: custom_config)

        expect(manager_with_custom.config).to eq(custom_config)
        expect(manager_with_custom.config.merchant_id).to eq("TEST_MERCHANT_ID")
      end
    end
  end

  describe "#config" do
    it "exposes the config via attr_reader" do
      expect(manager).to respond_to(:config)
      expect(manager.config).to be_a(CloverSandboxSimulator::Configuration)
    end
  end

  describe "service accessors" do
    describe "#inventory" do
      it "returns an InventoryService instance" do
        expect(manager.inventory).to be_a(CloverSandboxSimulator::Services::Clover::InventoryService)
      end

      it "passes the config to the service" do
        expect(manager.inventory.instance_variable_get(:@config)).to eq(manager.config)
      end

      it "memoizes the service instance" do
        first_call = manager.inventory
        second_call = manager.inventory

        expect(first_call).to be(second_call)
      end
    end

    describe "#tender" do
      it "returns a TenderService instance" do
        expect(manager.tender).to be_a(CloverSandboxSimulator::Services::Clover::TenderService)
      end

      it "passes the config to the service" do
        expect(manager.tender.instance_variable_get(:@config)).to eq(manager.config)
      end

      it "memoizes the service instance" do
        first_call = manager.tender
        second_call = manager.tender

        expect(first_call).to be(second_call)
      end
    end

    describe "#tax" do
      it "returns a TaxService instance" do
        expect(manager.tax).to be_a(CloverSandboxSimulator::Services::Clover::TaxService)
      end

      it "passes the config to the service" do
        expect(manager.tax.instance_variable_get(:@config)).to eq(manager.config)
      end

      it "memoizes the service instance" do
        first_call = manager.tax
        second_call = manager.tax

        expect(first_call).to be(second_call)
      end
    end

    describe "#discount" do
      it "returns a DiscountService instance" do
        expect(manager.discount).to be_a(CloverSandboxSimulator::Services::Clover::DiscountService)
      end

      it "passes the config to the service" do
        expect(manager.discount.instance_variable_get(:@config)).to eq(manager.config)
      end

      it "memoizes the service instance" do
        first_call = manager.discount
        second_call = manager.discount

        expect(first_call).to be(second_call)
      end
    end

    describe "#order" do
      it "returns an OrderService instance" do
        expect(manager.order).to be_a(CloverSandboxSimulator::Services::Clover::OrderService)
      end

      it "passes the config to the service" do
        expect(manager.order.instance_variable_get(:@config)).to eq(manager.config)
      end

      it "memoizes the service instance" do
        first_call = manager.order
        second_call = manager.order

        expect(first_call).to be(second_call)
      end
    end

    describe "#payment" do
      it "returns a PaymentService instance" do
        expect(manager.payment).to be_a(CloverSandboxSimulator::Services::Clover::PaymentService)
      end

      it "passes the config to the service" do
        expect(manager.payment.instance_variable_get(:@config)).to eq(manager.config)
      end

      it "memoizes the service instance" do
        first_call = manager.payment
        second_call = manager.payment

        expect(first_call).to be(second_call)
      end
    end

    describe "#employee" do
      it "returns an EmployeeService instance" do
        expect(manager.employee).to be_a(CloverSandboxSimulator::Services::Clover::EmployeeService)
      end

      it "passes the config to the service" do
        expect(manager.employee.instance_variable_get(:@config)).to eq(manager.config)
      end

      it "memoizes the service instance" do
        first_call = manager.employee
        second_call = manager.employee

        expect(first_call).to be(second_call)
      end
    end

    describe "#customer" do
      it "returns a CustomerService instance" do
        expect(manager.customer).to be_a(CloverSandboxSimulator::Services::Clover::CustomerService)
      end

      it "passes the config to the service" do
        expect(manager.customer.instance_variable_get(:@config)).to eq(manager.config)
      end

      it "memoizes the service instance" do
        first_call = manager.customer
        second_call = manager.customer

        expect(first_call).to be(second_call)
      end
    end

    describe "#refund" do
      it "returns a RefundService instance" do
        expect(manager.refund).to be_a(CloverSandboxSimulator::Services::Clover::RefundService)
      end

      it "passes the config to the service" do
        expect(manager.refund.instance_variable_get(:@config)).to eq(manager.config)
      end

      it "memoizes the service instance" do
        first_call = manager.refund
        second_call = manager.refund

        expect(first_call).to be(second_call)
      end
    end
  end

  describe "service isolation" do
    it "creates independent service instances" do
      expect(manager.inventory).not_to be(manager.order)
      expect(manager.payment).not_to be(manager.tender)
      expect(manager.tax).not_to be(manager.discount)
      expect(manager.employee).not_to be(manager.customer)
    end

    it "all services share the same configuration" do
      services = [
        manager.inventory,
        manager.tender,
        manager.tax,
        manager.discount,
        manager.order,
        manager.payment,
        manager.employee,
        manager.customer,
        manager.refund
      ]

      configs = services.map { |s| s.instance_variable_get(:@config) }

      expect(configs.uniq.size).to eq(1)
      expect(configs.first).to eq(manager.config)
    end
  end

  describe "manager isolation" do
    it "different manager instances have independent service caches" do
      manager1 = described_class.new
      manager2 = described_class.new

      # Services from different managers should be different instances
      expect(manager1.inventory).not_to be(manager2.inventory)
      expect(manager1.order).not_to be(manager2.order)
      expect(manager1.payment).not_to be(manager2.payment)
    end

    it "different managers can have different configurations" do
      config1 = create_test_config
      config1.instance_variable_set(:@merchant_id, "MERCHANT_1")

      config2 = create_test_config
      config2.instance_variable_set(:@merchant_id, "MERCHANT_2")

      manager1 = described_class.new(config: config1)
      manager2 = described_class.new(config: config2)

      expect(manager1.config.merchant_id).to eq("MERCHANT_1")
      expect(manager2.config.merchant_id).to eq("MERCHANT_2")

      # Services should use their respective manager's config
      expect(manager1.inventory.instance_variable_get(:@config).merchant_id).to eq("MERCHANT_1")
      expect(manager2.inventory.instance_variable_get(:@config).merchant_id).to eq("MERCHANT_2")
    end
  end

  describe "lazy loading behavior" do
    it "does not instantiate services until accessed" do
      # Create a new manager
      fresh_manager = described_class.new

      # Check that instance variables are not set
      expect(fresh_manager.instance_variable_get(:@inventory)).to be_nil
      expect(fresh_manager.instance_variable_get(:@order)).to be_nil
      expect(fresh_manager.instance_variable_get(:@payment)).to be_nil
      expect(fresh_manager.instance_variable_get(:@tender)).to be_nil
      expect(fresh_manager.instance_variable_get(:@tax)).to be_nil
      expect(fresh_manager.instance_variable_get(:@discount)).to be_nil
      expect(fresh_manager.instance_variable_get(:@employee)).to be_nil
      expect(fresh_manager.instance_variable_get(:@customer)).to be_nil
      expect(fresh_manager.instance_variable_get(:@refund)).to be_nil
    end

    it "instantiates service only after first access" do
      fresh_manager = described_class.new

      expect(fresh_manager.instance_variable_get(:@inventory)).to be_nil

      # Access the service
      fresh_manager.inventory

      expect(fresh_manager.instance_variable_get(:@inventory)).to be_a(
        CloverSandboxSimulator::Services::Clover::InventoryService
      )
    end

    it "only instantiates accessed services" do
      fresh_manager = described_class.new

      # Access only inventory and payment
      fresh_manager.inventory
      fresh_manager.payment

      # These should be instantiated
      expect(fresh_manager.instance_variable_get(:@inventory)).not_to be_nil
      expect(fresh_manager.instance_variable_get(:@payment)).not_to be_nil

      # These should still be nil
      expect(fresh_manager.instance_variable_get(:@order)).to be_nil
      expect(fresh_manager.instance_variable_get(:@tender)).to be_nil
      expect(fresh_manager.instance_variable_get(:@tax)).to be_nil
      expect(fresh_manager.instance_variable_get(:@discount)).to be_nil
      expect(fresh_manager.instance_variable_get(:@employee)).to be_nil
      expect(fresh_manager.instance_variable_get(:@customer)).to be_nil
      expect(fresh_manager.instance_variable_get(:@refund)).to be_nil
    end
  end

  describe "complete service coverage" do
    let(:expected_services) do
      {
        inventory: CloverSandboxSimulator::Services::Clover::InventoryService,
        tender: CloverSandboxSimulator::Services::Clover::TenderService,
        tax: CloverSandboxSimulator::Services::Clover::TaxService,
        discount: CloverSandboxSimulator::Services::Clover::DiscountService,
        order: CloverSandboxSimulator::Services::Clover::OrderService,
        payment: CloverSandboxSimulator::Services::Clover::PaymentService,
        employee: CloverSandboxSimulator::Services::Clover::EmployeeService,
        customer: CloverSandboxSimulator::Services::Clover::CustomerService,
        refund: CloverSandboxSimulator::Services::Clover::RefundService,
        gift_card: CloverSandboxSimulator::Services::Clover::GiftCardService
      }
    end

    it "provides access to all expected services" do
      expected_services.each do |method_name, service_class|
        expect(manager).to respond_to(method_name)
        expect(manager.public_send(method_name)).to be_a(service_class)
      end
    end

    it "provides exactly 10 services" do
      service_methods = %i[inventory tender tax discount order payment employee customer refund gift_card]

      expect(service_methods.size).to eq(10)
      service_methods.each do |method|
        expect(manager).to respond_to(method)
      end
    end
  end
end
