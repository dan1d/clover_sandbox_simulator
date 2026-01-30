# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name          = "pos_simulator"
  spec.version       = "1.0.0"
  spec.authors       = ["TheOwnerStack"]
  spec.email         = ["dev@theownerstack.com"]

  spec.summary       = "POS Simulator for generating realistic restaurant/retail data"
  spec.description   = "A clean Ruby gem for simulating Point of Sale operations in Clover, Square, and Stripe sandbox environments. Generates realistic orders, payments, and transaction data for testing accounting integrations."
  spec.homepage      = "https://github.com/theownerstack/pos_simulator"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.files = Dir.glob("{bin,lib}/**/*") + %w[README.md Gemfile]
  spec.bindir        = "bin"
  spec.executables   = ["simulate"]
  spec.require_paths = ["lib"]

  # Runtime dependencies
  spec.add_dependency "rest-client", "~> 2.1"
  spec.add_dependency "dotenv", "~> 3.0"
  spec.add_dependency "thor", "~> 1.3"          # CLI framework
  spec.add_dependency "faker", "~> 3.2"         # Realistic data generation
  spec.add_dependency "zeitwerk", "~> 2.6"      # Modern autoloading

  # Development dependencies
  spec.add_development_dependency "rspec", "~> 3.12"
  spec.add_development_dependency "rubocop", "~> 1.50"
  spec.add_development_dependency "webmock", "~> 3.18"
  spec.add_development_dependency "vcr", "~> 6.1"
end
