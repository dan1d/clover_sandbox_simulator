# frozen_string_literal: true

require "spec_helper"
require "factory_bot"

# Load factories from lib/ (shared between runtime and tests).
# Guarded to prevent "Factory already registered" if loaded elsewhere.
unless FactoryBot.factories.any? { |f| f.name == :business_type }
  factories_path = File.expand_path("../../lib/clover_sandbox_simulator/db/factories", __dir__)
  FactoryBot.definition_file_paths = [factories_path]
  FactoryBot.find_definitions
end

RSpec.describe "Factories", :db do
  include FactoryBot::Syntax::Methods

  # ── BusinessType ─────────────────────────────────────────────

  describe ":business_type factory" do
    it "creates a valid base business_type" do
      bt = create(:business_type)
      expect(bt).to be_persisted
      expect(bt).to be_valid
    end

    %i[restaurant cafe_bakery bar_nightclub food_truck fine_dining pizzeria
       retail_clothing retail_general salon_spa].each do |trait|
      it "creates a valid :#{trait} business_type" do
        bt = create(:business_type, trait)
        expect(bt).to be_persisted
        expect(bt.key).to eq(trait.to_s)
        expect(bt.order_profile).to be_a(Hash)
        expect(bt.order_profile).not_to be_empty
      end
    end

    it "sets correct industries" do
      expect(create(:business_type, :restaurant).industry).to eq("food")
      expect(create(:business_type, :retail_clothing).industry).to eq("retail")
      expect(create(:business_type, :salon_spa).industry).to eq("service")
    end
  end

  # ── Category ─────────────────────────────────────────────────

  describe ":category factory" do
    it "creates a valid base category" do
      cat = create(:category)
      expect(cat).to be_persisted
      expect(cat.business_type).to be_persisted
    end

    # One representative trait per business type
    {
      appetizers: "restaurant",
      coffee_espresso: "cafe_bakery",
      draft_beer: "bar_nightclub",
      tacos: "food_truck",
      first_course: "fine_dining",
      pizzas: "pizzeria",
      tops: "retail_clothing",
      electronics: "retail_general",
      haircuts: "salon_spa"
    }.each do |trait, expected_bt_key|
      it "creates a valid :#{trait} category linked to #{expected_bt_key}" do
        cat = create(:category, trait)
        expect(cat).to be_persisted
        expect(cat.business_type.key).to eq(expected_bt_key)
      end
    end
  end

  # ── Item (comprehensive trait check) ─────────────────────────

  describe ":item factory" do
    it "creates a valid base item" do
      item = create(:item)
      expect(item).to be_persisted
      expect(item.price).to be >= 0
    end

    # ── Restaurant items ─────────────────────────────────────
    restaurant_items = %i[
      buffalo_wings mozzarella_sticks loaded_nachos spinach_artichoke_dip calamari
      grilled_salmon ny_strip_steak chicken_parmesan pasta_primavera herb_roasted_chicken
      french_fries coleslaw mashed_potatoes side_salad onion_rings
      chocolate_lava_cake ny_cheesecake restaurant_tiramisu apple_pie ice_cream_sundae
      soft_drink iced_tea lemonade sparkling_water restaurant_coffee
    ]

    # ── Café & Bakery items ──────────────────────────────────
    cafe_items = %i[
      house_drip_coffee espresso cappuccino latte cold_brew
      croissant blueberry_muffin cinnamon_roll chocolate_chip_cookie
      avocado_toast breakfast_burrito acai_bowl yogurt_parfait
      turkey_club caprese_panini chicken_caesar_wrap blt
      berry_blast_smoothie green_detox_juice mango_tango_smoothie fresh_oj
    ]

    # ── Bar & Nightclub items ────────────────────────────────
    bar_items = %i[
      house_lager ipa stout wheat_beer
      margarita old_fashioned mojito espresso_martini
      whiskey_neat vodka_soda tequila_shot rum_and_coke
      house_red house_white prosecco rose
      bar_loaded_fries sliders bar_wings pretzel_bites
    ]

    # ── Food Truck items ─────────────────────────────────────
    truck_items = %i[
      carne_asada_taco al_pastor_taco fish_taco veggie_taco birria_taco
      classic_burrito burrito_bowl quesadilla truck_nachos
      chips_and_guac elote rice_and_beans horchata jarritos
    ]

    # ── Fine Dining items ────────────────────────────────────
    fine_items = %i[
      seared_foie_gras lobster_bisque tuna_tartare burrata_salad oysters_half_dozen
      wagyu_ribeye chilean_sea_bass rack_of_lamb duck_breast truffle_risotto
      creme_brulee chocolate_souffle tasting_plate cheese_board fine_tiramisu
    ]

    # ── Pizzeria items ───────────────────────────────────────
    pizza_items = %i[
      margherita pepperoni supreme hawaiian bbq_chicken_pizza meat_lovers
      classic_calzone meat_calzone stromboli spinach_calzone
      garlic_bread garden_salad caesar_salad garlic_knots fountain_drink cannoli
    ]

    # ── Retail Clothing items ────────────────────────────────
    clothing_items = %i[
      classic_tshirt button_down_shirt polo_shirt hoodie tank_top
      slim_fit_jeans chino_pants joggers shorts
      denim_jacket bomber_jacket puffer_vest rain_jacket
      baseball_cap beanie canvas_belt scarf
      canvas_sneakers leather_boots sandals running_shoes
    ]

    # ── Retail General items ─────────────────────────────────
    general_items = %i[
      wireless_earbuds phone_charger bluetooth_speaker power_bank
      scented_candle throw_pillow kitchen_towel_set ceramic_mug
      hand_soap body_lotion lip_balm sunscreen
      notebook pen_set desk_organizer sticky_notes
      granola_bar_3pack retail_sparkling_water trail_mix dark_chocolate_bar
    ]

    # ── Salon & Spa items ────────────────────────────────────
    salon_items = %i[
      womens_haircut mens_haircut childrens_haircut bang_trim
      full_color partial_highlights full_highlights balayage
      swedish_massage deep_tissue_massage hot_stone_massage facial
      manicure pedicure gel_manicure acrylic_full_set
    ]

    all_items = restaurant_items + cafe_items + bar_items + truck_items +
                fine_items + pizza_items + clothing_items + general_items + salon_items

    it "defines #{all_items.size} item traits" do
      expect(all_items.size).to be >= 168
    end

    all_items.each do |trait|
      it "builds a valid :#{trait} item" do
        item = build(:item, trait)
        expect(item).to be_valid, "#{trait}: #{item.errors.full_messages.join(', ')}"
        expect(item.name).to be_present
        expect(item.price).to be >= 0
        expect(item.sku).to be_present
      end
    end

    it "creates clothing items with variants" do
      item = build(:item, :classic_tshirt)
      expect(item.variants).to be_an(Array)
      expect(item.variants.first).to include("sizes", "colors")
    end

    it "creates salon items with unit and duration metadata" do
      item = build(:item, :womens_haircut)
      expect(item.unit).to eq("session")
      expect(item.metadata).to include("duration_minutes" => 45)
    end

    it "creates spa items with hour unit" do
      item = build(:item, :swedish_massage)
      expect(item.unit).to eq("hour")
      expect(item.metadata).to include("duration_minutes" => 60)
    end
  end

  # ── SimulatedOrder ───────────────────────────────────────────

  describe ":simulated_order factory" do
    it "creates a valid base order" do
      order = create(:simulated_order)
      expect(order).to be_persisted
      expect(order.status).to eq("open")
    end

    it "creates a :paid order" do
      order = create(:simulated_order, :paid)
      expect(order.status).to eq("paid")
      expect(order.total).to be > 0
      expect(order.clover_order_id).to be_present
    end

    it "creates a :refunded order" do
      order = create(:simulated_order, :refunded)
      expect(order.status).to eq("refunded")
    end

    it "creates a :failed order" do
      order = create(:simulated_order, :failed)
      expect(order.status).to eq("failed")
      expect(order.metadata).to include("error" => "Payment declined")
    end

    it "creates a :with_payment order (has associated payment)" do
      order = create(:simulated_order, :with_payment)
      expect(order.simulated_payments.count).to eq(1)
      expect(order.simulated_payments.first.status).to eq("paid")
    end

    it "creates a :with_split_payment order (two payments)" do
      order = create(:simulated_order, :with_split_payment)
      expect(order.simulated_payments.count).to eq(2)
      total = order.simulated_payments.sum(&:amount)
      expect(total).to eq(order.total)
    end

    it "supports meal period and dining option traits" do
      order = create(:simulated_order, :paid, :lunch_order, :takeout)
      expect(order.meal_period).to eq("lunch")
      expect(order.dining_option).to eq("TO_GO")
    end
  end

  # ── SimulatedPayment ─────────────────────────────────────────

  describe ":simulated_payment factory" do
    it "creates a valid base payment" do
      payment = create(:simulated_payment)
      expect(payment).to be_persisted
      expect(payment.status).to eq("pending")
    end

    it "creates a :success payment" do
      payment = create(:simulated_payment, :success)
      expect(payment.status).to eq("paid")
      expect(payment.clover_payment_id).to be_present
    end

    it "creates a :failed payment" do
      payment = create(:simulated_payment, :failed)
      expect(payment.status).to eq("failed")
    end

    it "creates a :split payment" do
      payment = create(:simulated_payment, :split)
      expect(payment.status).to eq("paid")
      expect(payment.amount).to eq(750)
    end

    it "supports tender traits" do
      cash = build(:simulated_payment, :cash_tender)
      expect(cash.tender_name).to eq("Cash")

      credit = build(:simulated_payment, :credit_tender)
      expect(credit.tender_name).to eq("Credit Card")

      debit = build(:simulated_payment, :debit_tender)
      expect(debit.tender_name).to eq("Debit Card")

      gift = build(:simulated_payment, :gift_card_tender)
      expect(gift.tender_name).to eq("Gift Card")
    end
  end

  # ── ApiRequest ───────────────────────────────────────────────

  describe ":api_request factory" do
    it "creates a valid base request" do
      req = create(:api_request)
      expect(req).to be_persisted
      expect(req.http_method).to eq("GET")
    end

    it "creates a :get request" do
      req = build(:api_request, :get)
      expect(req.http_method).to eq("GET")
      expect(req.response_status).to eq(200)
    end

    it "creates a :post request" do
      req = build(:api_request, :post)
      expect(req.http_method).to eq("POST")
      expect(req.response_status).to eq(201)
    end

    it "creates an :error request" do
      req = build(:api_request, :error)
      expect(req.response_status).to eq(500)
      expect(req.error_message).to eq("Internal Server Error")
    end

    it "creates a :not_found request" do
      req = build(:api_request, :not_found)
      expect(req.response_status).to eq(404)
    end

    it "creates a :rate_limited request" do
      req = build(:api_request, :rate_limited)
      expect(req.response_status).to eq(429)
    end

    it "supports resource traits" do
      req = build(:api_request, :order_resource)
      expect(req.resource_type).to eq("Order")
      expect(req.resource_id).to be_present

      req = build(:api_request, :item_resource)
      expect(req.resource_type).to eq("Item")
    end
  end

  # ── DailySummary ─────────────────────────────────────────────

  describe ":daily_summary factory" do
    it "creates a valid base summary" do
      summary = create(:daily_summary)
      expect(summary).to be_persisted
      expect(summary.order_count).to eq(0)
    end

    it "creates a :busy_day summary" do
      summary = create(:daily_summary, :busy_day)
      expect(summary.order_count).to eq(85)
      expect(summary.total_revenue).to eq(425_000)
      expect(summary.breakdown).to include("by_meal_period", "by_tender")
    end

    it "creates a :slow_day summary" do
      summary = create(:daily_summary, :slow_day)
      expect(summary.order_count).to eq(12)
      expect(summary.total_revenue).to eq(48_000)
    end
  end

  # ── Cross-factory integration ────────────────────────────────

  describe "cross-factory integration" do
    it "builds a complete restaurant setup end-to-end" do
      bt = create(:business_type, :restaurant)
      cat = create(:category, :appetizers, business_type: bt)
      item = create(:item, :buffalo_wings, category: cat)
      order = create(:simulated_order, :paid, business_type: bt)
      payment = create(:simulated_payment, :success, simulated_order: order)

      expect(bt.categories).to include(cat)
      expect(cat.items).to include(item)
      expect(order.simulated_payments).to include(payment)
      expect(item.price_dollars).to eq(12.99)
    end

    it "builds a clothing item with variants" do
      bt = create(:business_type, :retail_clothing)
      cat = create(:category, :tops, business_type: bt)
      item = create(:item, :classic_tshirt, category: cat)

      expect(item.variants.first).to include("sizes" => %w[S M L XL])
      expect(item.variants.first).to include("colors" => %w[Black White Navy])
    end

    it "builds a salon service with duration" do
      bt = create(:business_type, :salon_spa)
      cat = create(:category, :haircuts, business_type: bt)
      item = create(:item, :womens_haircut, category: cat)

      expect(item.unit).to eq("session")
      expect(item.metadata["duration_minutes"]).to eq(45)
      expect(item.price_dollars).to eq(55.0)
    end
  end
end
