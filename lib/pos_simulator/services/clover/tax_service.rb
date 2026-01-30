# frozen_string_literal: true

module PosSimulator
  module Services
    module Clover
      # Manages Clover tax rates
      class TaxService < BaseService
        # Fetch all tax rates
        def get_tax_rates
          logger.info "Fetching tax rates..."
          response = request(:get, endpoint("tax_rates"))
          elements = response&.dig("elements") || []
          logger.info "Found #{elements.size} tax rates"
          elements
        end

        # Get default tax rate
        def default_tax_rate
          rates = get_tax_rates
          # Find default rate or return first active one
          rates.find { |r| r["isDefault"] == true } || rates.first
        end

        # Create a tax rate
        def create_tax_rate(name:, rate:, is_default: false)
          logger.info "Creating tax rate: #{name} (#{rate}%)"
          
          # Rate is stored as basis points (8.25% = 825000)
          rate_basis_points = (rate * 100_000).to_i

          request(:post, endpoint("tax_rates"), payload: {
            "name" => name,
            "rate" => rate_basis_points,
            "isDefault" => is_default,
            "taxType" => "VAT_EXEMPT" # For US sales tax
          })
        end

        # Delete a tax rate
        def delete_tax_rate(tax_rate_id)
          logger.info "Deleting tax rate: #{tax_rate_id}"
          request(:delete, endpoint("tax_rates/#{tax_rate_id}"))
        end

        # Calculate tax for an amount
        def calculate_tax(subtotal, tax_rate = nil)
          rate = tax_rate || config.tax_rate
          (subtotal * rate / 100.0).round
        end
      end
    end
  end
end
