# frozen_string_literal: true

require "spec_helper"

RSpec.describe "DataLoader DB/JSON compatibility", :db, :integration do
  let(:loader_class) { CloverSandboxSimulator::Generators::DataLoader }

  # Test with two different business types to satisfy AC
  %i[restaurant].each do |bt|
    context "for #{bt} business type" do
      before do
        CloverSandboxSimulator::Seeder.seed!(business_type: bt)
      end

      let(:db_loader) { loader_class.new(business_type: bt) }
      let(:json_loader) do
        l = loader_class.new(business_type: bt)
        allow(CloverSandboxSimulator::Database).to receive(:connected?).and_return(false)
        l
      end

      # ── Categories ──────────────────────────────────────────────

      describe "categories format parity" do
        it "DB and JSON return the same keys" do
          db_keys   = db_loader.categories.first.keys.sort
          json_keys = json_loader.categories.first.keys.sort

          expect(db_keys).to eq(json_keys),
            "DB keys #{db_keys} != JSON keys #{json_keys}"
        end

        it "DB and JSON values have matching types" do
          db_cat   = db_loader.categories.first
          json_cat = json_loader.categories.first

          db_cat.each do |key, value|
            next if value.nil?

            expect(json_cat[key].class).to eq(value.class),
              "Category key '#{key}': DB type #{value.class} != JSON type #{json_cat[key].class}"
          end
        end

        it "both return non-empty arrays" do
          expect(db_loader.categories).to be_an(Array)
          expect(db_loader.categories).not_to be_empty
          expect(json_loader.categories).to be_an(Array)
          expect(json_loader.categories).not_to be_empty
        end

        it "both include 'Appetizers'" do
          db_names   = db_loader.categories.map { |c| c["name"] }
          json_names = json_loader.categories.map { |c| c["name"] }

          expect(db_names).to include("Appetizers")
          expect(json_names).to include("Appetizers")
        end

        it "sort_order is Integer in both" do
          db_loader.categories.each do |cat|
            expect(cat["sort_order"]).to be_a(Integer),
              "DB category '#{cat['name']}' sort_order is #{cat['sort_order'].class}"
          end

          json_loader.categories.each do |cat|
            expect(cat["sort_order"]).to be_a(Integer),
              "JSON category '#{cat['name']}' sort_order is #{cat['sort_order'].class}"
          end
        end
      end

      # ── Items ───────────────────────────────────────────────────

      describe "items format parity" do
        it "both have the core keys: name, price, category" do
          %w[name price category].each do |key|
            db_item = db_loader.items.first
            json_item = json_loader.items.first

            expect(db_item).to have_key(key),
              "DB item missing key '#{key}'"
            expect(json_item).to have_key(key),
              "JSON item missing key '#{key}'"
          end
        end

        it "price is Integer (cents) in both" do
          db_loader.items.each do |item|
            expect(item["price"]).to be_a(Integer),
              "DB item '#{item['name']}' price is #{item['price'].class}"
            expect(item["price"]).to be > 0
          end

          json_loader.items.each do |item|
            expect(item["price"]).to be_a(Integer),
              "JSON item '#{item['name']}' price is #{item['price'].class}"
            expect(item["price"]).to be > 0
          end
        end

        it "name is String in both" do
          db_loader.items.each do |item|
            expect(item["name"]).to be_a(String)
          end

          json_loader.items.each do |item|
            expect(item["name"]).to be_a(String)
          end
        end

        it "category is a String category name in both" do
          db_loader.items.each do |item|
            expect(item["category"]).to be_a(String)
            expect(item["category"]).not_to be_empty
          end

          json_loader.items.each do |item|
            expect(item["category"]).to be_a(String)
            expect(item["category"]).not_to be_empty
          end
        end

        it "both return non-empty arrays" do
          expect(db_loader.items.size).to be > 0
          expect(json_loader.items.size).to be > 0
        end
      end

      # ── Tax rates ───────────────────────────────────────────────

      describe "tax_rates format parity" do
        it "both return arrays with same structure" do
          db_rates   = db_loader.tax_rates
          json_rates = json_loader.tax_rates

          expect(db_rates).to be_an(Array)
          expect(json_rates).to be_an(Array)
          expect(db_rates).not_to be_empty
          expect(json_rates).not_to be_empty

          # Same keys
          expect(db_rates.first.keys.sort).to eq(json_rates.first.keys.sort)
        end

        it "rate is a Numeric in both" do
          db_loader.tax_rates.each do |tr|
            expect(tr["rate"]).to be_a(Numeric),
              "DB tax rate '#{tr['name']}' rate is #{tr['rate'].class}"
          end

          json_loader.tax_rates.each do |tr|
            expect(tr["rate"]).to be_a(Numeric),
              "JSON tax rate '#{tr['name']}' rate is #{tr['rate'].class}"
          end
        end
      end

      # ── JSON fallback still works ──────────────────────────────

      describe "JSON fallback" do
        it "loads data without DB" do
          expect(json_loader.data_source).to eq(:json)
          expect(json_loader.categories).not_to be_empty
          expect(json_loader.items).not_to be_empty
          expect(json_loader.discounts).not_to be_empty
          expect(json_loader.tenders).not_to be_empty
        end

        it "combos always come from JSON regardless of DB" do
          db_combos   = db_loader.combos
          json_combos = json_loader.combos

          expect(db_combos).to eq(json_combos)
        end

        it "coupon_codes always come from JSON regardless of DB" do
          db_coupons   = db_loader.coupon_codes
          json_coupons = json_loader.coupon_codes

          expect(db_coupons).to eq(json_coupons)
        end
      end

      # ── items_for_category consistency ─────────────────────────

      describe "items_for_category" do
        it "returns correct items from DB path" do
          appetizers = db_loader.items_for_category("Appetizers")

          expect(appetizers).to be_an(Array)
          expect(appetizers).not_to be_empty
          appetizers.each do |item|
            expect(item["category"]).to eq("Appetizers")
          end
        end

        it "returns correct items from JSON path" do
          appetizers = json_loader.items_for_category("Appetizers")

          expect(appetizers).to be_an(Array)
          expect(appetizers).not_to be_empty
          appetizers.each do |item|
            expect(item["category"]).to eq("Appetizers")
          end
        end
      end
    end
  end

  # ── Second business type (retail_clothing) ─────────────────────

  context "for retail_clothing business type" do
    before do
      CloverSandboxSimulator::Seeder.seed!(business_type: :retail_clothing)
    end

    let(:db_loader) { loader_class.new(business_type: :retail_clothing) }

    it "loads categories from DB" do
      expect(db_loader.data_source).to eq(:db)
      cats = db_loader.categories
      expect(cats).to be_an(Array)
      expect(cats).not_to be_empty
      expect(cats.first).to have_key("name")
      expect(cats.first).to have_key("sort_order")
    end

    it "loads items from DB with variants" do
      items = db_loader.items
      expect(items).not_to be_empty

      items_with_variants = items.select { |i| i.key?("variants") }
      expect(items_with_variants).not_to be_empty,
        "Clothing items should have variants"

      items_with_variants.each do |item|
        expect(item["variants"]).to be_an(Array)
        expect(item["variants"]).not_to be_empty
      end
    end

    it "items have SKU values" do
      db_loader.items.each do |item|
        next unless item.key?("sku")

        expect(item["sku"]).to be_a(String)
        expect(item["sku"]).not_to be_empty
      end
    end
  end
end
