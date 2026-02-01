# frozen_string_literal: true

module CloverSandboxSimulator
  module Services
    module Clover
      # Manages Clover gift card operations
      # Handles balance management, purchase, reload, and redemption
      class GiftCardService < BaseService
        # Standard gift card denominations in cents
        DENOMINATIONS = [2500, 5000, 10000, 2000, 7500].freeze

        # Gift card number format: 16 digits
        CARD_NUMBER_LENGTH = 16

        # Fetch all gift cards for the merchant
        #
        # @return [Array<Hash>] List of gift cards
        def fetch_gift_cards
          logger.info "Fetching gift cards..."
          response = request(:get, endpoint("gift_cards"))
          elements = response&.dig("elements") || []
          logger.info "Found #{elements.size} gift cards"
          elements
        end

        # Create/activate a new gift card
        #
        # @param amount [Integer] Initial balance in cents
        # @param card_number [String, nil] Optional 16-digit card number (auto-generated if nil)
        # @return [Hash, nil] Created gift card or nil on failure
        def create_gift_card(amount:, card_number: nil)
          card_number ||= generate_card_number
          logger.info "Creating gift card #{mask_card_number(card_number)} with balance $#{amount / 100.0}"

          payload = {
            "cardNumber" => card_number,
            "amount" => amount,
            "status" => "ACTIVE"
          }

          response = request(:post, endpoint("gift_cards"), payload: payload)

          if response && response["id"]
            logger.info "Gift card created: #{response['id']}"
          else
            logger.error "Failed to create gift card: #{response.inspect}"
          end

          response
        end

        # Get a specific gift card by ID
        #
        # @param gift_card_id [String] The gift card ID
        # @return [Hash, nil] Gift card details or nil
        def get_gift_card(gift_card_id)
          logger.info "Fetching gift card: #{gift_card_id}"
          request(:get, endpoint("gift_cards/#{gift_card_id}"))
        end

        # Check balance for a gift card
        #
        # @param gift_card_id [String] The gift card ID
        # @return [Integer] Balance in cents, or 0 if not found
        def check_balance(gift_card_id)
          gift_card = get_gift_card(gift_card_id)
          balance = gift_card&.dig("balance") || 0
          logger.info "Gift card #{gift_card_id} balance: $#{balance / 100.0}"
          balance
        end

        # Reload/add balance to a gift card
        #
        # @param gift_card_id [String] The gift card ID
        # @param amount [Integer] Amount to add in cents
        # @return [Hash, nil] Updated gift card or nil on failure
        def reload_gift_card(gift_card_id, amount:)
          logger.info "Reloading gift card #{gift_card_id} with $#{amount / 100.0}"

          payload = {
            "amount" => amount
          }

          response = request(:post, endpoint("gift_cards/#{gift_card_id}/reload"), payload: payload)

          if response
            new_balance = response["balance"] || 0
            logger.info "Gift card reloaded. New balance: $#{new_balance / 100.0}"
          else
            logger.error "Failed to reload gift card"
          end

          response
        end

        # Redeem/use balance from a gift card
        #
        # @param gift_card_id [String] The gift card ID
        # @param amount [Integer] Amount to redeem in cents
        # @return [Hash] Result with :success, :amount_redeemed, :remaining_balance, :shortfall
        def redeem_gift_card(gift_card_id, amount:)
          logger.info "Redeeming $#{amount / 100.0} from gift card #{gift_card_id}"

          current_balance = check_balance(gift_card_id)

          if current_balance <= 0
            logger.warn "Gift card has no balance"
            return {
              success: false,
              amount_redeemed: 0,
              remaining_balance: 0,
              shortfall: amount,
              message: "Gift card has no balance"
            }
          end

          # Calculate redemption amount (may be partial if insufficient balance)
          redeem_amount = [amount, current_balance].min
          shortfall = amount - redeem_amount

          payload = {
            "amount" => redeem_amount
          }

          response = request(:post, endpoint("gift_cards/#{gift_card_id}/redeem"), payload: payload)

          if response
            remaining = response["balance"] || 0
            logger.info "Redeemed $#{redeem_amount / 100.0}. Remaining balance: $#{remaining / 100.0}"

            if shortfall > 0
              logger.info "Shortfall of $#{shortfall / 100.0} - will need additional payment"
            end

            {
              success: true,
              amount_redeemed: redeem_amount,
              remaining_balance: remaining,
              shortfall: shortfall,
              gift_card: response
            }
          else
            logger.error "Failed to redeem gift card"
            {
              success: false,
              amount_redeemed: 0,
              remaining_balance: current_balance,
              shortfall: amount,
              message: "Failed to redeem gift card"
            }
          end
        end

        # Find a gift card with sufficient balance
        #
        # @param minimum_balance [Integer] Minimum balance required in cents
        # @return [Hash, nil] Gift card with sufficient balance or nil
        def find_card_with_balance(minimum_balance: 0)
          gift_cards = fetch_gift_cards
          eligible = gift_cards.select do |gc|
            gc["status"] == "ACTIVE" && (gc["balance"] || 0) >= minimum_balance
          end

          if eligible.any?
            selected = eligible.sample
            logger.info "Found eligible gift card: #{selected['id']} with balance $#{(selected['balance'] || 0) / 100.0}"
            selected
          else
            logger.info "No gift cards found with minimum balance $#{minimum_balance / 100.0}"
            nil
          end
        end

        # Select a random gift card for payment
        # May return a card with insufficient balance for partial payment scenarios
        #
        # @return [Hash, nil] Random active gift card or nil
        def random_gift_card
          gift_cards = fetch_gift_cards
          active_cards = gift_cards.select { |gc| gc["status"] == "ACTIVE" }

          if active_cards.any?
            active_cards.sample
          else
            logger.info "No active gift cards available"
            nil
          end
        end

        # Generate a valid 16-digit gift card number
        #
        # @return [String] 16-digit card number
        def generate_card_number
          # Format: 4 groups of 4 digits, starting with 6xxx (common gift card prefix)
          prefix = "6#{rand(0..9)}#{rand(0..9)}#{rand(0..9)}"
          middle1 = format("%04d", rand(0..9999))
          middle2 = format("%04d", rand(0..9999))
          suffix = format("%04d", rand(0..9999))

          "#{prefix}#{middle1}#{middle2}#{suffix}"
        end

        # Get a random denomination amount
        #
        # @return [Integer] Amount in cents
        def random_denomination
          DENOMINATIONS.sample
        end

        private

        # Mask card number for logging (show first 4 and last 4 digits)
        #
        # @param card_number [String] Full card number
        # @return [String] Masked card number
        def mask_card_number(card_number)
          return card_number if card_number.nil? || card_number.length < 8

          "#{card_number[0..3]}********#{card_number[-4..]}"
        end
      end
    end
  end
end
