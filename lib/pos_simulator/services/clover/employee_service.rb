# frozen_string_literal: true

require "faker"

module PosSimulator
  module Services
    module Clover
      # Manages Clover employees
      class EmployeeService < BaseService
        # Note: OWNER and ADMIN roles may not be available in sandbox
        ROLES = %w[MANAGER EMPLOYEE].freeze

        # Fetch all employees
        def get_employees
          logger.info "Fetching employees..."
          response = request(:get, endpoint("employees"))
          elements = response&.dig("elements") || []
          # Filter active employees
          active = elements.select { |e| e["deleted"] != true }
          logger.info "Found #{active.size} active employees"
          active
        end

        # Get a specific employee
        def get_employee(employee_id)
          request(:get, endpoint("employees/#{employee_id}"))
        end

        # Create an employee
        def create_employee(name:, email: nil, role: "EMPLOYEE", pin: nil)
          logger.info "Creating employee: #{name}"
          
          payload = {
            "name" => name,
            "role" => role
          }
          payload["email"] = email if email
          payload["pin"] = pin if pin

          request(:post, endpoint("employees"), payload: payload)
        end

        # Create sample employees if needed
        def ensure_employees(count: 3)
          existing = get_employees
          return existing if existing.size >= count

          needed = count - existing.size
          logger.info "Creating #{needed} sample employees..."

          new_employees = []
          needed.times do
            name = Faker::Name.name
            # Use example.com domain - Clover rejects .test domains
            # Remove special chars, collapse dots, strip leading/trailing dots
            safe_name = name.downcase.gsub(/[^a-z0-9]/, ".").gsub(/\.+/, ".").gsub(/^\.|\.$/, "")
            employee = create_employee(
              name: name,
              email: "#{safe_name}@example.com",
              role: ROLES.sample
            )
            new_employees << employee if employee
          end

          existing + new_employees
        end

        # Get a random employee
        def random_employee
          employees = get_employees
          employees.sample
        end

        # Delete an employee
        def delete_employee(employee_id)
          logger.info "Deleting employee: #{employee_id}"
          request(:delete, endpoint("employees/#{employee_id}"))
        end
      end
    end
  end
end
