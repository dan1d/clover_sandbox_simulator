# frozen_string_literal: true

require "faker"

module CloverSandboxSimulator
  module Services
    module Clover
      # Manages Clover customers
      class CustomerService < BaseService
        # Fetch all customers
        def get_customers
          logger.info "Fetching customers..."
          response = request(:get, endpoint("customers"))
          elements = response&.dig("elements") || []
          logger.info "Found #{elements.size} customers"
          elements
        end

        # Get a specific customer
        def get_customer(customer_id)
          request(:get, endpoint("customers/#{customer_id}"))
        end

        # Create a customer
        def create_customer(first_name:, last_name:, email: nil, phone: nil)
          logger.info "Creating customer: #{first_name} #{last_name}"

          payload = {
            "firstName" => first_name,
            "lastName" => last_name
          }
          payload["emailAddresses"] = [{ "emailAddress" => email }] if email
          payload["phoneNumbers"] = [{ "phoneNumber" => phone }] if phone

          request(:post, endpoint("customers"), payload: payload)
        end

        # Create sample customers if needed
        # Default customer names for deterministic setup
        DEFAULT_CUSTOMERS = [
          { first: "John", last: "Smith", phone: "555-100-0001" },
          { first: "Jane", last: "Doe", phone: "555-100-0002" },
          { first: "Bob", last: "Johnson", phone: "555-100-0003" },
          { first: "Alice", last: "Williams", phone: "555-100-0004" },
          { first: "Charlie", last: "Brown", phone: "555-100-0005" },
          { first: "Diana", last: "Davis", phone: "555-100-0006" },
          { first: "Eve", last: "Miller", phone: "555-100-0007" },
          { first: "Frank", last: "Wilson", phone: "555-100-0008" },
          { first: "Grace", last: "Moore", phone: "555-100-0009" },
          { first: "Henry", last: "Taylor", phone: "555-100-0010" }
        ].freeze

        # Create sample customers if needed
        # @param count [Integer] Minimum number of customers to ensure exist
        # @param deterministic [Boolean] If true, uses predefined names for consistency
        def ensure_customers(count: 10, deterministic: true)
          existing = get_customers
          return existing if existing.size >= count

          needed = count - existing.size
          logger.info "Creating #{needed} sample customers..."

          new_customers = []
          needed.times do |i|
            if deterministic && i < DEFAULT_CUSTOMERS.size
              cust_data = DEFAULT_CUSTOMERS[existing.size + i] || DEFAULT_CUSTOMERS.last
              first = cust_data[:first]
              last = cust_data[:last]
              phone = cust_data[:phone]
            else
              first = Faker::Name.first_name
              last = Faker::Name.last_name
              phone = Faker::PhoneNumber.cell_phone
            end

            # Use example.com domain - Clover rejects .test domains
            # Remove special chars, collapse dots, strip leading/trailing dots
            safe_first = first.downcase.gsub(/[^a-z0-9]/, "")
            safe_last = last.downcase.gsub(/[^a-z0-9]/, "")
            customer = create_customer(
              first_name: first,
              last_name: last,
              email: "#{safe_first}.#{safe_last}@example.com",
              phone: phone
            )
            new_customers << customer if customer
          end

          existing + new_customers
        end

        # Ensure specific customers exist by name (idempotent)
        # @param customer_list [Array<Hash>] Array of { first_name:, last_name:, email:, phone: }
        # @return [Array<Hash>] All customers (existing + created)
        def ensure_specific_customers(customer_list)
          existing = get_customers
          existing_emails = existing.map { |c| c["emailAddresses"]&.first&.dig("emailAddress")&.downcase }.compact

          new_customers = []
          customer_list.each do |cust_data|
            email = cust_data[:email]&.downcase
            next if email && existing_emails.include?(email)

            customer = create_customer(
              first_name: cust_data[:first_name],
              last_name: cust_data[:last_name],
              email: cust_data[:email],
              phone: cust_data[:phone]
            )
            new_customers << customer if customer
          end

          existing + new_customers
        end

        # Get a random customer (70% chance of returning a customer, 30% anonymous)
        def random_customer
          return nil if rand < 0.3 # 30% anonymous orders

          customers = get_customers
          customers.sample
        end

        # Delete a customer
        def delete_customer(customer_id)
          logger.info "Deleting customer: #{customer_id}"
          request(:delete, endpoint("customers/#{customer_id}"))
        end
      end
    end
  end
end
