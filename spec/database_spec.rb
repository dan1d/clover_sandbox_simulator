# frozen_string_literal: true

require "spec_helper"

RSpec.describe CloverSandboxSimulator::Database do
  describe ".connected?" do
    it "returns false when no connection is established" do
      # Disconnect any existing connection from spec_helper
      begin
        described_class.disconnect!
      rescue StandardError
        nil
      end

      expect(described_class.connected?).to be false
    end
  end

  describe ".connect!" do
    it "raises ArgumentError for non-PostgreSQL URLs" do
      expect {
        described_class.connect!("mysql://localhost:3306/test")
      }.to raise_error(ArgumentError, /Expected a PostgreSQL URL/)
    end

    it "raises ArgumentError for random strings" do
      expect {
        described_class.connect!("not-a-url")
      }.to raise_error(ArgumentError, /Expected a PostgreSQL URL/)
    end

    it "does not raise ArgumentError for valid postgres:// URLs" do
      described_class.connect!("postgres://localhost:5432/nonexistent_db_xyz")
    rescue ActiveRecord::NoDatabaseError, ActiveRecord::ConnectionNotEstablished
      # Expected — the URL scheme was accepted, connection failed for other reasons
    end

    it "does not raise ArgumentError for valid postgresql:// URLs" do
      described_class.connect!("postgresql://localhost:5432/nonexistent_db_xyz")
    rescue ActiveRecord::NoDatabaseError, ActiveRecord::ConnectionNotEstablished
      # Expected — the URL scheme was accepted, connection failed for other reasons
    end
  end

  describe ".test_database_url" do
    it "returns URL with clover_simulator_test database name" do
      url = described_class.test_database_url
      expect(url).to include("clover_simulator_test")
    end

    it "replaces database name when given a base URL" do
      url = described_class.test_database_url(base_url: "postgres://user:pass@db.example.com:5432/mydb")
      expect(url).to eq("postgres://user:pass@db.example.com:5432/clover_simulator_test")
    end

    it "handles base URL without credentials" do
      url = described_class.test_database_url(base_url: "postgres://localhost:5432/dev_db")
      expect(url).to eq("postgres://localhost:5432/clover_simulator_test")
    end
  end

  describe ".migrate!" do
    it "raises error when not connected" do
      begin
        described_class.disconnect!
      rescue StandardError
        nil
      end

      expect {
        described_class.migrate!
      }.to raise_error(CloverSandboxSimulator::Error, /Database not connected/)
    end
  end

  describe ".seed!" do
    it "raises error when not connected" do
      begin
        described_class.disconnect!
      rescue StandardError
        nil
      end

      expect {
        described_class.seed!
      }.to raise_error(CloverSandboxSimulator::Error, /Database not connected/)
    end
  end

  describe "MIGRATIONS_PATH" do
    it "points to the db/migrate directory" do
      expect(described_class::MIGRATIONS_PATH).to end_with("lib/clover_sandbox_simulator/db/migrate")
    end

    it "directory exists" do
      expect(Dir.exist?(described_class::MIGRATIONS_PATH)).to be true
    end
  end

  describe "TEST_DATABASE" do
    it "is clover_simulator_test" do
      expect(described_class::TEST_DATABASE).to eq("clover_simulator_test")
    end
  end

  describe "URL sanitization" do
    # Access the private method for testing via send
    it "masks password in database URL" do
      sanitized = described_class.send(:sanitize_url, "postgres://user:secret@localhost:5432/mydb")
      expect(sanitized).not_to include("secret")
      expect(sanitized).to include("***")
      expect(sanitized).to include("localhost:5432/mydb")
    end

    it "masks username in database URL" do
      sanitized = described_class.send(:sanitize_url, "postgres://myuser:secret@localhost:5432/mydb")
      expect(sanitized).not_to include("myuser")
      expect(sanitized).not_to include("secret")
    end

    it "handles URLs without credentials" do
      sanitized = described_class.send(:sanitize_url, "postgres://localhost:5432/mydb")
      expect(sanitized).to eq("postgres://localhost:5432/mydb")
    end
  end
end
