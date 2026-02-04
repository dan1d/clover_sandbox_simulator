# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CloverSandboxSimulator::Services::Clover::EmployeeService do
  before { stub_clover_credentials }

  let(:service) { described_class.new }
  let(:base_url) { 'https://sandbox.dev.clover.com/v3/merchants/TEST_MERCHANT_ID' }

  let(:active_employees) do
    [
      { 'id' => 'EMP1', 'name' => 'John Doe', 'email' => 'john@example.com', 'role' => 'MANAGER', 'deleted' => false },
      { 'id' => 'EMP2', 'name' => 'Jane Smith', 'email' => 'jane@example.com', 'role' => 'EMPLOYEE',
        'deleted' => false },
      { 'id' => 'EMP3', 'name' => 'Bob Wilson', 'email' => 'bob@example.com', 'role' => 'EMPLOYEE' }
    ]
  end

  let(:deleted_employee) do
    { 'id' => 'EMP4', 'name' => 'Deleted User', 'email' => 'deleted@example.com', 'role' => 'EMPLOYEE',
      'deleted' => true }
  end

  let(:all_employees) { active_employees + [deleted_employee] }

  describe '#get_employees' do
    it 'fetches all active employees' do
      stub_request(:get, "#{base_url}/employees")
        .to_return(
          status: 200,
          body: { elements: all_employees }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      employees = service.get_employees

      expect(employees.size).to eq(3)
      expect(employees.map { |e| e['id'] }).to contain_exactly('EMP1', 'EMP2', 'EMP3')
    end

    it 'filters out deleted employees' do
      stub_request(:get, "#{base_url}/employees")
        .to_return(
          status: 200,
          body: { elements: all_employees }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      employees = service.get_employees

      expect(employees.none? { |e| e['deleted'] == true }).to be true
    end

    it 'returns empty array when no employees exist' do
      stub_request(:get, "#{base_url}/employees")
        .to_return(
          status: 200,
          body: { elements: [] }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      employees = service.get_employees

      expect(employees).to eq([])
    end

    it 'handles nil response gracefully' do
      stub_request(:get, "#{base_url}/employees")
        .to_return(
          status: 200,
          body: {}.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      employees = service.get_employees

      expect(employees).to eq([])
    end

    it 'includes employees without explicit deleted field as active' do
      employees_without_deleted = [
        { 'id' => 'EMP1', 'name' => 'John Doe', 'role' => 'MANAGER' }
      ]

      stub_request(:get, "#{base_url}/employees")
        .to_return(
          status: 200,
          body: { elements: employees_without_deleted }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      employees = service.get_employees

      expect(employees.size).to eq(1)
      expect(employees.first['id']).to eq('EMP1')
    end
  end

  describe '#get_employee' do
    it 'fetches a specific employee by ID' do
      employee_data = { 'id' => 'EMP1', 'name' => 'John Doe', 'email' => 'john@example.com', 'role' => 'MANAGER' }

      stub_request(:get, "#{base_url}/employees/EMP1")
        .to_return(
          status: 200,
          body: employee_data.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      employee = service.get_employee('EMP1')

      expect(employee['id']).to eq('EMP1')
      expect(employee['name']).to eq('John Doe')
      expect(employee['email']).to eq('john@example.com')
      expect(employee['role']).to eq('MANAGER')
    end

    it 'raises ApiError for non-existent employee' do
      stub_request(:get, "#{base_url}/employees/NONEXISTENT")
        .to_return(
          status: 404,
          body: { message: 'Not found' }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      expect do
        service.get_employee('NONEXISTENT')
      end.to raise_error(CloverSandboxSimulator::ApiError, /404/)
    end
  end

  describe '#create_employee' do
    it 'creates an employee with name and default role' do
      stub_request(:post, "#{base_url}/employees")
        .with(body: hash_including('name' => 'New Employee', 'role' => 'EMPLOYEE'))
        .to_return(
          status: 200,
          body: { id: 'EMP_NEW', name: 'New Employee', role: 'EMPLOYEE' }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      employee = service.create_employee(name: 'New Employee')

      expect(employee['id']).to eq('EMP_NEW')
      expect(employee['name']).to eq('New Employee')
      expect(employee['role']).to eq('EMPLOYEE')
    end

    it 'creates an employee with all attributes' do
      stub_request(:post, "#{base_url}/employees")
        .with(body: hash_including(
          'name' => 'Manager Person',
          'email' => 'manager@example.com',
          'role' => 'MANAGER',
          'pin' => '1234'
        ))
        .to_return(
          status: 200,
          body: {
            id: 'EMP_MGR',
            name: 'Manager Person',
            email: 'manager@example.com',
            role: 'MANAGER',
            pin: '1234'
          }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      employee = service.create_employee(
        name: 'Manager Person',
        email: 'manager@example.com',
        role: 'MANAGER',
        pin: '1234'
      )

      expect(employee['id']).to eq('EMP_MGR')
      expect(employee['email']).to eq('manager@example.com')
      expect(employee['role']).to eq('MANAGER')
    end

    it 'excludes email from payload when not provided' do
      stub_request(:post, "#{base_url}/employees")
        .with { |req| !req.body.include?('email') }
        .to_return(
          status: 200,
          body: { id: 'EMP_NEW', name: 'No Email Employee' }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      employee = service.create_employee(name: 'No Email Employee')

      expect(employee['id']).to eq('EMP_NEW')
    end

    it 'excludes pin from payload when not provided' do
      stub_request(:post, "#{base_url}/employees")
        .with { |req| !req.body.include?('pin') }
        .to_return(
          status: 200,
          body: { id: 'EMP_NEW', name: 'No Pin Employee' }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      employee = service.create_employee(name: 'No Pin Employee')

      expect(employee['id']).to eq('EMP_NEW')
    end

    it 'creates an employee with MANAGER role' do
      stub_request(:post, "#{base_url}/employees")
        .with(body: hash_including('role' => 'MANAGER'))
        .to_return(
          status: 200,
          body: { id: 'EMP_MGR', name: 'Boss', role: 'MANAGER' }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      employee = service.create_employee(name: 'Boss', role: 'MANAGER')

      expect(employee['role']).to eq('MANAGER')
    end
  end

  describe '#ensure_employees' do
    context 'when enough employees exist' do
      it 'returns existing employees without creating new ones' do
        stub_request(:get, "#{base_url}/employees")
          .to_return(
            status: 200,
            body: { elements: active_employees }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )

        employees = service.ensure_employees(count: 3)

        expect(employees.size).to eq(3)
        expect(WebMock).not_to have_requested(:post, "#{base_url}/employees")
      end

      it 'returns existing employees when count exceeds minimum' do
        stub_request(:get, "#{base_url}/employees")
          .to_return(
            status: 200,
            body: { elements: active_employees }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )

        employees = service.ensure_employees(count: 2)

        expect(employees.size).to eq(3)
        expect(WebMock).not_to have_requested(:post, "#{base_url}/employees")
      end
    end

    context 'when employees need to be created' do
      before do
        # Allow Faker to generate predictable names
        allow(Faker::Name).to receive(:name).and_return('Test Person')
      end

      it 'creates missing employees to meet count threshold' do
        stub_request(:get, "#{base_url}/employees")
          .to_return(
            status: 200,
            body: { elements: [active_employees.first] }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )

        stub_request(:post, "#{base_url}/employees")
          .to_return(
            status: 200,
            body: { id: 'EMP_NEW', name: 'Test Person' }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )

        employees = service.ensure_employees(count: 3)

        expect(employees.size).to eq(3)
        expect(WebMock).to have_requested(:post, "#{base_url}/employees").times(2)
      end

      it 'uses example.com domain for employee emails' do
        stub_request(:get, "#{base_url}/employees")
          .to_return(
            status: 200,
            body: { elements: [] }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )

        # In deterministic mode, first employee is "Alex Manager"
        stub_request(:post, "#{base_url}/employees")
          .with(body: hash_including('email' => 'alex.manager@example.com'))
          .to_return(
            status: 200,
            body: { id: 'EMP_NEW', name: 'Alex Manager', email: 'alex.manager@example.com' }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )

        service.ensure_employees(count: 1)

        expect(WebMock).to have_requested(:post, "#{base_url}/employees")
          .with(body: hash_including('email' => 'alex.manager@example.com'))
      end

      it 'sanitizes special characters in email address (non-deterministic mode)' do
        allow(Faker::Name).to receive(:name).and_return("O'Brien-Smith III")

        stub_request(:get, "#{base_url}/employees")
          .to_return(
            status: 200,
            body: { elements: [] }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )

        stub_request(:post, "#{base_url}/employees")
          .with(body: hash_including('email' => 'o.brien.smith.iii@example.com'))
          .to_return(
            status: 200,
            body: { id: 'EMP_NEW' }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )

        # Use non-deterministic mode to test Faker name sanitization
        service.ensure_employees(count: 1, deterministic: false)

        # Should convert to safe email without apostrophe or hyphen
        expect(WebMock).to have_requested(:post, "#{base_url}/employees")
          .with(body: hash_including('email' => 'o.brien.smith.iii@example.com'))
      end

      it 'assigns role from ROLES constant' do
        allow(Faker::Name).to receive(:name).and_return('Test Employee')

        stub_request(:get, "#{base_url}/employees")
          .to_return(
            status: 200,
            body: { elements: [] }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )

        stub_request(:post, "#{base_url}/employees")
          .to_return(
            status: 200,
            body: { id: 'EMP_NEW', role: 'EMPLOYEE' }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )

        service.ensure_employees(count: 1)

        # Verify the role is one of the valid ROLES
        expect(WebMock).to(have_requested(:post, "#{base_url}/employees")
          .with do |req|
            body = JSON.parse(req.body)
            described_class::ROLES.include?(body['role'])
          end)
      end

      it 'raises ApiError when employee creation fails' do
        allow(Faker::Name).to receive(:name).and_return('Test Person')

        stub_request(:get, "#{base_url}/employees")
          .to_return(
            status: 200,
            body: { elements: [] }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )

        stub_request(:post, "#{base_url}/employees")
          .to_return(
            status: 400,
            body: { message: 'Invalid request' }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )

        expect do
          service.ensure_employees(count: 2)
        end.to raise_error(CloverSandboxSimulator::ApiError, /400/)
      end
    end

    context 'with no existing employees' do
      it 'creates the specified count of employees' do
        allow(Faker::Name).to receive(:name).and_return('New Person')

        stub_request(:get, "#{base_url}/employees")
          .to_return(
            status: 200,
            body: { elements: [] }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )

        stub_request(:post, "#{base_url}/employees")
          .to_return(
            status: 200,
            body: { id: 'EMP_NEW', name: 'New Person' }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )

        employees = service.ensure_employees(count: 5)

        expect(employees.size).to eq(5)
        expect(WebMock).to have_requested(:post, "#{base_url}/employees").times(5)
      end
    end
  end

  describe '#random_employee' do
    it 'returns a random employee from the list' do
      stub_request(:get, "#{base_url}/employees")
        .to_return(
          status: 200,
          body: { elements: active_employees }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      employee = service.random_employee

      expect(active_employees.map { |e| e['id'] }).to include(employee['id'])
    end

    it 'returns nil when no employees exist' do
      stub_request(:get, "#{base_url}/employees")
        .to_return(
          status: 200,
          body: { elements: [] }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      employee = service.random_employee

      expect(employee).to be_nil
    end

    it 'only returns active employees' do
      stub_request(:get, "#{base_url}/employees")
        .to_return(
          status: 200,
          body: { elements: all_employees }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      # Call multiple times to increase chance of catching deleted employee
      10.times do
        employee = service.random_employee
        next if employee.nil?

        expect(employee['deleted']).not_to eq(true)
      end
    end
  end

  describe '#delete_employee' do
    it 'deletes an employee by ID' do
      stub_request(:delete, "#{base_url}/employees/EMP1")
        .to_return(
          status: 200,
          body: {}.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      result = service.delete_employee('EMP1')

      expect(WebMock).to have_requested(:delete, "#{base_url}/employees/EMP1")
      expect(result).not_to be_nil
    end

    it 'raises ApiError when deleting non-existent employee' do
      stub_request(:delete, "#{base_url}/employees/NONEXISTENT")
        .to_return(
          status: 404,
          body: { message: 'Not found' }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      expect do
        service.delete_employee('NONEXISTENT')
      end.to raise_error(CloverSandboxSimulator::ApiError, /404/)
    end

    it 'makes DELETE request to correct endpoint' do
      stub_request(:delete, "#{base_url}/employees/EMP123")
        .to_return(
          status: 200,
          body: {}.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      service.delete_employee('EMP123')

      expect(WebMock).to have_requested(:delete, "#{base_url}/employees/EMP123").once
    end
  end

  describe '::ROLES' do
    it 'contains valid role values' do
      expect(described_class::ROLES).to contain_exactly('MANAGER', 'EMPLOYEE')
    end

    it 'does not include OWNER or ADMIN roles' do
      expect(described_class::ROLES).not_to include('OWNER', 'ADMIN')
    end
  end
end
