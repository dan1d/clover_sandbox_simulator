# frozen_string_literal: true

require "faker"

module PosSimulator
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
        def ensure_customers(count: 10)
          existing = get_customers
          return existing if existing.size >= count

          needed = count - existing.size
          logger.info "Creating #{needed} sample customers..."

          new_customers = []
          needed.times do
            first = Faker::Name.first_name
            last = Faker::Name.last_name
            # Use example.com domain - Clover rejects .test domains
            # Remove special chars, collapse dots, strip leading/trailing dots
            safe_first = first.downcase.gsub(/[^a-z0-9]/, "")
            safe_last = last.downcase.gsub(/[^a-z0-9]/, "")
            customer = create_customer(
              first_name: first,
              last_name: last,
              email: "#{safe_first}.#{safe_last}@example.com",
              phone: Faker::PhoneNumber.cell_phone
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
