# frozen_string_literal: true

module CloverSandboxSimulator
  module Services
    module Clover
      # Manages Clover payment tenders (Cash, Credit Card, Gift Card, etc.)
      class TenderService < BaseService
        # Tenders that work via the Platform API (non-card payments)
        PLATFORM_API_TENDERS = %w[
          com.clover.tender.cash
          com.clover.tender.check
          com.clover.tender.external_gift_card
          com.clover.tender.external_payment
        ].freeze

        # Canonical labelKey values for card tenders — payments routed
        # through the Ecommerce API rather than the Platform API.
        CARD_TENDER_KEYS = %w[
          com.clover.tender.credit_card
          com.clover.tender.debit_card
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
        # Use get_all_payment_tenders instead if Ecommerce API is available.
        def get_safe_tenders
          tenders = get_tenders

          safe = tenders.reject do |tender|
            card_tender?(tender)
          end

          logger.info "Found #{safe.size} sandbox-safe tenders"
          safe
        end

        # Get ALL payment tenders including credit/debit cards.
        # Card tenders are included when the Ecommerce API is configured;
        # payments using these tenders are routed through the Ecommerce API
        # (tokenize → charge) instead of the Platform API.
        def get_all_payment_tenders
          tenders = get_tenders

          unless config.ecommerce_enabled?
            logger.info "Ecommerce API not configured — excluding card tenders"
            return tenders.reject { |t| card_tender?(t) }
          end

          logger.info "Ecommerce API available — including #{tenders.count { |t| card_tender?(t) }} card tender(s)"
          tenders
        end

        # Returns true if the tender is a credit or debit card.
        # Checks the canonical `labelKey` against CARD_TENDER_KEYS first,
        # then falls back to substring matching on the human-readable label
        # (handles custom/renamed tenders).
        def card_tender?(tender)
          label_key = tender["labelKey"]&.downcase || ""

          # Fast path: known Clover card tender labelKeys
          return true if CARD_TENDER_KEYS.include?(label_key)

          # Fallback: match on human-readable label for custom tenders
          label = tender["label"]&.downcase || ""
          label.include?("credit") || label.include?("debit")
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
