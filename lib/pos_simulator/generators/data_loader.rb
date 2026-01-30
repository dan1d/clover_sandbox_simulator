# frozen_string_literal: true

module PosSimulator
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

      def items_for_category(category_name)
        items.select { |item| item["category"] == category_name }
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
        File.join(PosSimulator.root, "lib", "pos_simulator", "data", business_type.to_s)
      end
    end
  end
end
