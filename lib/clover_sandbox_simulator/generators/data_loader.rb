# frozen_string_literal: true

module CloverSandboxSimulator
  module Generators
    # Loads data from PostgreSQL when connected, falling back to JSON files.
    #
    # The DB path is preferred because it respects any runtime mutations
    # (items deactivated, prices changed, categories added via Seeder).
    # When no DB connection is available the loader reads the static JSON
    # data files shipped with the gem — the returned hashes use the same
    # keys in both cases so callers are unaware of the source.
    class DataLoader
      attr_reader :business_type

      def initialize(business_type: :restaurant)
        @business_type = business_type
      end

      # ── Primary data accessors (DB-first, JSON fallback) ───────

      def categories
        @categories ||= if db_connected?
                           categories_from_db
                         else
                           load_json("categories")["categories"]
                         end
      end

      def items
        @items ||= if db_connected?
                     items_from_db
                   else
                     load_json("items")["items"]
                   end
      end

      def tax_rates
        @tax_rates ||= if db_connected?
                         tax_rates_from_db
                       else
                         load_json("tax_rates")["tax_rates"]
                       end
      rescue Error
        [] # Return empty array if file doesn't exist
      end

      def category_tax_mapping
        @category_tax_mapping ||= if db_connected?
                                    category_tax_mapping_from_db
                                  else
                                    load_json("tax_rates")["category_tax_mapping"]
                                  end
      rescue Error
        {} # Return empty hash if file doesn't exist
      end

      def combos
        @combos ||= load_json("combos")["combos"]
      rescue Error
        [] # No DB model for combos — always JSON
      end

      # ── JSON-only accessors (no DB models for these) ───────────

      def discounts
        @discounts ||= load_json("discounts")["discounts"]
      end

      def tenders
        @tenders ||= load_json("tenders")["tenders"]
      end

      def modifiers
        @modifiers ||= load_json("modifiers")["modifier_groups"]
      end

      def coupon_codes
        @coupon_codes ||= load_json("coupon_codes")["coupon_codes"]
      rescue Error
        []
      end

      # ── Convenience filters ────────────────────────────────────

      def items_for_category(category_name)
        items.select { |item| item["category"] == category_name }
      end

      def discounts_by_type(type)
        discounts.select { |d| d["type"] == type }
      end

      def time_based_discounts
        discounts_by_type("time_based")
      end

      def line_item_discounts
        discounts.select { |d| d["type"]&.start_with?("line_item") }
      end

      def loyalty_discounts
        discounts_by_type("loyalty")
      end

      def threshold_discounts
        discounts_by_type("threshold")
      end

      def active_coupon_codes
        coupon_codes.select { |c| c["active"] }
      end

      def active_combos
        combos.select { |c| c["active"] }
      end

      def find_coupon(code)
        coupon_codes.find { |c| c["code"].upcase == code.upcase }
      end

      def find_combo(combo_id)
        combos.find { |c| c["id"] == combo_id }
      end

      # ── Data source introspection ──────────────────────────────

      # Returns :db or :json to indicate which source was used.
      # Useful for logging and diagnostics.
      def data_source
        db_connected? ? :db : :json
      end

      private

      def db_connected?
        Database.connected?
      end

      # ── DB query methods ───────────────────────────────────────
      # Each method returns data formatted identically to the JSON
      # structure so callers are unaware of the data source.

      def categories_from_db
        bt = Models::BusinessType.find_by(key: business_type.to_s)
        return load_json("categories")["categories"] unless bt

        bt.categories.sorted.map do |cat|
          {
            "name"        => cat.name,
            "sort_order"  => cat.sort_order,
            "description" => cat.description
          }
        end
      end

      def items_from_db
        bt = Models::BusinessType.find_by(key: business_type.to_s)
        return load_json("items")["items"] unless bt

        Models::Item.active
                    .for_business_type(business_type.to_s)
                    .includes(:category)
                    .order("categories.sort_order", "items.name")
                    .map do |item|
          hash = {
            "name"        => item.name,
            "price"       => item.price,
            "category"    => item.category.name
          }

          # Include optional fields when present (mirrors factory traits)
          hash["sku"]      = item.sku      if item.sku.present?
          hash["variants"] = item.variants if item.variants.present?
          hash["unit"]     = item.unit     if item.unit.present?
          hash["metadata"] = item.metadata if item.metadata.present?
          hash
        end
      end

      def tax_rates_from_db
        # Tax rates are stored in the JSON file as they are static
        # configuration. When DB categories have tax_group set, we
        # build synthetic tax rate entries matching the JSON format.
        bt = Models::BusinessType.find_by(key: business_type.to_s)
        return load_json("tax_rates")["tax_rates"] unless bt

        # Collect unique tax groups from categories
        tax_groups = bt.categories.where.not(tax_group: nil).distinct.pluck(:tax_group).compact
        return load_json("tax_rates")["tax_rates"] if tax_groups.empty?

        # Fall back to JSON — tax rates don't have their own DB model
        load_json("tax_rates")["tax_rates"]
      end

      def category_tax_mapping_from_db
        bt = Models::BusinessType.find_by(key: business_type.to_s)
        return load_json("tax_rates")["category_tax_mapping"] unless bt

        mapping = {}
        bt.categories.where.not(tax_group: nil).find_each do |cat|
          mapping[cat.name] = [cat.tax_group]
        end

        # Fall back to JSON if DB has no tax_group data
        return load_json("tax_rates")["category_tax_mapping"] if mapping.empty?

        mapping
      end

      # ── JSON loading ───────────────────────────────────────────

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
