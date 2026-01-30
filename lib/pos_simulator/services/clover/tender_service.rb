# frozen_string_literal: true

module PosSimulator
  module Services
    module Clover
      # Manages Clover payment tenders (Cash, Gift Card, etc.)
      class TenderService < BaseService
        # Tenders that work reliably in Clover sandbox
        # NOTE: Credit Card and Debit Card are BROKEN in sandbox - do not use!
        SANDBOX_SAFE_TENDERS = %w[
          com.clover.tender.cash
          com.clover.tender.check
          com.clover.tender.external_gift_card
          com.clover.tender.external_payment
        ].freeze

        # Fetch all tenders
        def get_tenders
          logger.info "Fetching tenders..."
          response = request(:get, endpoint("tenders"))
          elements = response&.dig("elements") || []
          
          # Filter to enabled tenders only
          enabled = elements.select { |t| t["enabled"] == true }
          logger.info "Found #{enabled.size} enabled tenders"
          enabled
        end

        # Get sandbox-safe tenders (excludes credit/debit cards)
        def get_safe_tenders
          tenders = get_tenders
          
          safe = tenders.reject do |tender|
            label = tender["label"]&.downcase || ""
            label_key = tender["labelKey"]&.downcase || ""
            
            # Exclude credit and debit cards - they're broken in sandbox
            label.include?("credit") || 
              label.include?("debit") || 
              label_key.include?("credit") || 
              label_key.include?("debit")
          end

          logger.info "Found #{safe.size} sandbox-safe tenders"
          safe
        end

        # Get a specific tender by label
        def find_tender_by_label(label)
          tenders = get_tenders
          tenders.find { |t| t["label"]&.downcase == label.downcase }
        end

        # Get cash tender
        def cash_tender
          find_tender_by_label("Cash") || get_safe_tenders.first
        end

        # Create a custom tender
        def create_tender(label:, label_key: nil, enabled: true, opens_cash_drawer: false)
          logger.info "Creating tender: #{label}"
          
          payload = {
            "label" => label,
            "labelKey" => label_key || "com.clover.tender.#{label.downcase.gsub(/\s+/, '_')}",
            "enabled" => enabled,
            "opensCashDrawer" => opens_cash_drawer
          }

          request(:post, endpoint("tenders"), payload: payload)
        end

        # Select random safe tenders for split payment
        # Returns array of tender IDs with split percentages
        def select_split_tenders(num_splits: nil)
          tenders = get_safe_tenders
          return [] if tenders.empty?

          # Determine number of splits (1-3)
          num_splits ||= rand(1..3)
          num_splits = [num_splits, tenders.size].min

          # Select random tenders
          selected = tenders.sample(num_splits)
          
          # Generate random split percentages that sum to 100
          percentages = generate_split_percentages(num_splits)

          selected.zip(percentages).map do |tender, percentage|
            { tender: tender, percentage: percentage }
          end
        end

        private

        def generate_split_percentages(count)
          return [100] if count == 1

          # Generate random split points
          points = Array.new(count - 1) { rand(10..90) }.sort
          
          # Calculate percentages from split points
          percentages = []
          prev = 0
          points.each do |point|
            percentages << (point - prev)
            prev = point
          end
          percentages << (100 - prev)

          # Ensure no percentage is less than 5%
          percentages.map { |p| [p, 5].max }
        end
      end
    end
  end
end
