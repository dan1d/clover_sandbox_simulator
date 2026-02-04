# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name          = "clover_sandbox_simulator"
  spec.version       = "1.1.0"
  spec.authors       = ["dan1d"]
  spec.email         = ["dan1d@users.noreply.github.com"]

  spec.summary       = "Clover Sandbox Simulator for generating realistic restaurant data"
  spec.description   = "A Ruby gem for simulating Point of Sale operations in Clover sandbox environments. Generates realistic restaurant orders, payments, and transaction data for testing integrations with Clover's API."
  spec.homepage      = "https://github.com/dan1d/clover_sandbox_simulator"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.files = Dir.glob("{bin,lib}/**/*") + %w[README.md Gemfile]
  spec.bindir        = "bin"
  spec.executables   = ["simulate"]
  spec.require_paths = ["lib"]

  # Runtime dependencies
  spec.add_dependency "rest-client", "~> 2.1"
  spec.add_dependency "dotenv", "~> 3.0"
  spec.add_dependency "thor", "~> 1.3"                    # CLI framework
  spec.add_dependency "faker", "~> 3.2"                   # Realistic data generation
  spec.add_dependency "zeitwerk", "~> 2.6"                # Modern autoloading
  spec.add_dependency "omniauth-clover-oauth2", "~> 1.1"  # Clover OAuth2 authentication
  spec.add_dependency "concurrent-ruby", "~> 1.2"         # Parallel execution

  # Development dependencies
  spec.add_development_dependency "rspec", "~> 3.12"
  spec.add_development_dependency "rubocop", "~> 1.50"
  spec.add_development_dependency "webmock", "~> 3.18"
  spec.add_development_dependency "vcr", "~> 6.1"
end
