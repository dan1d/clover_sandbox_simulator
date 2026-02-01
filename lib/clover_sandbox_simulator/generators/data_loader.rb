# frozen_string_literal: true

module CloverSandboxSimulator
  module Generators
    # Loads data from JSON files for different business types
    class DataLoader
      attr_reader :business_type

      def initialize(business_type: :restaurant)
        @business_type = business_type
      end

      def categories
        @categories ||= load_json("categories")["categories"]
      end

      def items
        @items ||= load_json("items")["items"]
      end

      def discounts
        @discounts ||= load_json("discounts")["discounts"]
      end

      def tenders
        @tenders ||= load_json("tenders")["tenders"]
      end

      def modifiers
        @modifiers ||= load_json("modifiers")["modifier_groups"]
      end

      # Load coupon codes
      def coupon_codes
        @coupon_codes ||= load_json("coupon_codes")["coupon_codes"]
      rescue Error
        [] # Return empty array if file doesn't exist
      end

      # Load combo definitions
      def combos
        @combos ||= load_json("combos")["combos"]
      rescue Error
        [] # Return empty array if file doesn't exist
      end

      def items_for_category(category_name)
        items.select { |item| item["category"] == category_name }
      end

      # Get discounts by type
      def discounts_by_type(type)
        discounts.select { |d| d["type"] == type }
      end

      # Get time-based discounts
      def time_based_discounts
        discounts_by_type("time_based")
      end

      # Get line-item discounts
      def line_item_discounts
        discounts.select { |d| d["type"]&.start_with?("line_item") }
      end

      # Get loyalty discounts
      def loyalty_discounts
        discounts_by_type("loyalty")
      end

      # Get threshold discounts
      def threshold_discounts
        discounts_by_type("threshold")
      end

      # Get active coupon codes
      def active_coupon_codes
        coupon_codes.select { |c| c["active"] }
      end

      # Get active combos
      def active_combos
        combos.select { |c| c["active"] }
      end

      # Find coupon by code
      def find_coupon(code)
        coupon_codes.find { |c| c["code"].upcase == code.upcase }
      end

      # Find combo by ID
      def find_combo(combo_id)
        combos.find { |c| c["id"] == combo_id }
      end

      private

      def load_json(filename)
        path = File.join(data_path, "#{filename}.json")

        unless File.exist?(path)
          raise Error, "Data file not found: #{path}"
        end

        JSON.parse(File.read(path))
      end

      def data_path
        File.join(CloverSandboxSimulator.root, "lib", "clover_sandbox_simulator", "data", business_type.to_s)
      end
    end
  end
end
