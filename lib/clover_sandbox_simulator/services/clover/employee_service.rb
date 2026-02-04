# frozen_string_literal: true

require "faker"

module CloverSandboxSimulator
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

        # Default employee names for deterministic setup
        DEFAULT_EMPLOYEES = [
          { name: "Alex Manager", role: "MANAGER" },
          { name: "Jordan Server", role: "EMPLOYEE" },
          { name: "Casey Cook", role: "EMPLOYEE" },
          { name: "Riley Host", role: "EMPLOYEE" },
          { name: "Morgan Bartender", role: "EMPLOYEE" }
        ].freeze

        # Create sample employees if needed
        # @param count [Integer] Minimum number of employees to ensure exist
        # @param deterministic [Boolean] If true, uses predefined names for consistency
        def ensure_employees(count: 3, deterministic: true)
          existing = get_employees
          return existing if existing.size >= count

          needed = count - existing.size
          logger.info "Creating #{needed} sample employees..."

          new_employees = []
          needed.times do |i|
            if deterministic && i < DEFAULT_EMPLOYEES.size
              emp_data = DEFAULT_EMPLOYEES[existing.size + i] || DEFAULT_EMPLOYEES.last
              name = emp_data[:name]
              role = emp_data[:role]
            else
              name = Faker::Name.name
              role = ROLES.sample
            end

            # Use example.com domain - Clover rejects .test domains
            # Remove special chars, collapse dots, strip leading/trailing dots
            safe_name = name.downcase.gsub(/[^a-z0-9]/, ".").gsub(/\.+/, ".").gsub(/^\.|\.$/, "")
            employee = create_employee(
              name: name,
              email: "#{safe_name}@example.com",
              role: role
            )
            new_employees << employee if employee
          end

          existing + new_employees
        end

        # Ensure specific employees exist by name (idempotent)
        # @param employee_names [Array<Hash>] Array of { name:, role:, email: }
        # @return [Array<Hash>] All employees (existing + created)
        def ensure_specific_employees(employee_names)
          existing = get_employees
          existing_names = existing.map { |e| e["name"]&.downcase }

          new_employees = []
          employee_names.each do |emp_data|
            next if existing_names.include?(emp_data[:name]&.downcase)

            safe_name = emp_data[:name].downcase.gsub(/[^a-z0-9]/, ".").gsub(/\.+/, ".").gsub(/^\.|\.$/, "")
            employee = create_employee(
              name: emp_data[:name],
              email: emp_data[:email] || "#{safe_name}@example.com",
              role: emp_data[:role] || "EMPLOYEE"
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
