# frozen_string_literal: true

# ~168 item traits across 9 business types and 38 categories.
# Each trait sets name, price (cents), sku, and associates with the correct
# category (which in turn associates with the correct business type).
#
# Usage:
#   build(:item, :buffalo_wings)                    # auto-creates category + business_type
#   create(:item, :buffalo_wings, category: my_cat) # override category

FactoryBot.define do
  factory :item, class: "CloverSandboxSimulator::Models::Item" do
    association :category
    sequence(:name) { |n| "Item #{n}" }
    price { 999 } # cents
    active { true }
    variants { [] }
    metadata { {} }

    # ═══════════════════════════════════════════════════════════
    #  RESTAURANT  (5 categories, 25 items)
    # ═══════════════════════════════════════════════════════════

    # ── Appetizers ─────────────────────────────────────────────

    trait :buffalo_wings do
      name { "Buffalo Wings" }
      price { 1299 }
      sku { "REST-APP-001" }
      association :category, factory: [:category, :appetizers]
    end

    trait :mozzarella_sticks do
      name { "Mozzarella Sticks" }
      price { 999 }
      sku { "REST-APP-002" }
      association :category, factory: [:category, :appetizers]
    end

    trait :loaded_nachos do
      name { "Loaded Nachos" }
      price { 1199 }
      sku { "REST-APP-003" }
      association :category, factory: [:category, :appetizers]
    end

    trait :spinach_artichoke_dip do
      name { "Spinach Artichoke Dip" }
      price { 1099 }
      sku { "REST-APP-004" }
      association :category, factory: [:category, :appetizers]
    end

    trait :calamari do
      name { "Calamari" }
      price { 1399 }
      sku { "REST-APP-005" }
      association :category, factory: [:category, :appetizers]
    end

    # ── Entrées ────────────────────────────────────────────────

    trait :grilled_salmon do
      name { "Grilled Salmon" }
      price { 2299 }
      sku { "REST-ENT-001" }
      association :category, factory: [:category, :entrees]
    end

    trait :ny_strip_steak do
      name { "NY Strip Steak" }
      price { 2899 }
      sku { "REST-ENT-002" }
      association :category, factory: [:category, :entrees]
    end

    trait :chicken_parmesan do
      name { "Chicken Parmesan" }
      price { 1899 }
      sku { "REST-ENT-003" }
      association :category, factory: [:category, :entrees]
    end

    trait :pasta_primavera do
      name { "Pasta Primavera" }
      price { 1599 }
      sku { "REST-ENT-004" }
      association :category, factory: [:category, :entrees]
    end

    trait :herb_roasted_chicken do
      name { "Herb Roasted Chicken" }
      price { 1999 }
      sku { "REST-ENT-005" }
      association :category, factory: [:category, :entrees]
    end

    # ── Sides ──────────────────────────────────────────────────

    trait :french_fries do
      name { "French Fries" }
      price { 599 }
      sku { "REST-SID-001" }
      association :category, factory: [:category, :sides]
    end

    trait :coleslaw do
      name { "Coleslaw" }
      price { 499 }
      sku { "REST-SID-002" }
      association :category, factory: [:category, :sides]
    end

    trait :mashed_potatoes do
      name { "Mashed Potatoes" }
      price { 699 }
      sku { "REST-SID-003" }
      association :category, factory: [:category, :sides]
    end

    trait :side_salad do
      name { "Side Salad" }
      price { 549 }
      sku { "REST-SID-004" }
      association :category, factory: [:category, :sides]
    end

    trait :onion_rings do
      name { "Onion Rings" }
      price { 699 }
      sku { "REST-SID-005" }
      association :category, factory: [:category, :sides]
    end

    # ── Desserts ───────────────────────────────────────────────

    trait :chocolate_lava_cake do
      name { "Chocolate Lava Cake" }
      price { 999 }
      sku { "REST-DES-001" }
      association :category, factory: [:category, :desserts]
    end

    trait :ny_cheesecake do
      name { "New York Cheesecake" }
      price { 899 }
      sku { "REST-DES-002" }
      association :category, factory: [:category, :desserts]
    end

    trait :restaurant_tiramisu do
      name { "Tiramisu" }
      price { 1099 }
      sku { "REST-DES-003" }
      association :category, factory: [:category, :desserts]
    end

    trait :apple_pie do
      name { "Apple Pie à la Mode" }
      price { 799 }
      sku { "REST-DES-004" }
      association :category, factory: [:category, :desserts]
    end

    trait :ice_cream_sundae do
      name { "Ice Cream Sundae" }
      price { 699 }
      sku { "REST-DES-005" }
      association :category, factory: [:category, :desserts]
    end

    # ── Beverages ──────────────────────────────────────────────

    trait :soft_drink do
      name { "Soft Drink" }
      price { 299 }
      sku { "REST-BEV-001" }
      association :category, factory: [:category, :beverages]
    end

    trait :iced_tea do
      name { "Iced Tea" }
      price { 299 }
      sku { "REST-BEV-002" }
      association :category, factory: [:category, :beverages]
    end

    trait :lemonade do
      name { "Lemonade" }
      price { 349 }
      sku { "REST-BEV-003" }
      association :category, factory: [:category, :beverages]
    end

    trait :sparkling_water do
      name { "Sparkling Water" }
      price { 399 }
      sku { "REST-BEV-004" }
      association :category, factory: [:category, :beverages]
    end

    trait :restaurant_coffee do
      name { "Coffee" }
      price { 249 }
      sku { "REST-BEV-005" }
      association :category, factory: [:category, :beverages]
    end

    # ═══════════════════════════════════════════════════════════
    #  CAFÉ & BAKERY  (5 categories, 21 items)
    # ═══════════════════════════════════════════════════════════

    # ── Coffee & Espresso ──────────────────────────────────────

    trait :house_drip_coffee do
      name { "House Drip Coffee" }
      price { 299 }
      sku { "CAFE-COF-001" }
      association :category, factory: [:category, :coffee_espresso]
    end

    trait :espresso do
      name { "Espresso" }
      price { 349 }
      sku { "CAFE-COF-002" }
      association :category, factory: [:category, :coffee_espresso]
    end

    trait :cappuccino do
      name { "Cappuccino" }
      price { 499 }
      sku { "CAFE-COF-003" }
      association :category, factory: [:category, :coffee_espresso]
    end

    trait :latte do
      name { "Latte" }
      price { 549 }
      sku { "CAFE-COF-004" }
      association :category, factory: [:category, :coffee_espresso]
    end

    trait :cold_brew do
      name { "Cold Brew" }
      price { 499 }
      sku { "CAFE-COF-005" }
      association :category, factory: [:category, :coffee_espresso]
    end

    # ── Pastries ───────────────────────────────────────────────

    trait :croissant do
      name { "Butter Croissant" }
      price { 399 }
      sku { "CAFE-PAS-001" }
      association :category, factory: [:category, :pastries]
    end

    trait :blueberry_muffin do
      name { "Blueberry Muffin" }
      price { 349 }
      sku { "CAFE-PAS-002" }
      association :category, factory: [:category, :pastries]
    end

    trait :cinnamon_roll do
      name { "Cinnamon Roll" }
      price { 449 }
      sku { "CAFE-PAS-003" }
      association :category, factory: [:category, :pastries]
    end

    trait :chocolate_chip_cookie do
      name { "Chocolate Chip Cookie" }
      price { 299 }
      sku { "CAFE-PAS-004" }
      association :category, factory: [:category, :pastries]
    end

    # ── Breakfast ──────────────────────────────────────────────

    trait :avocado_toast do
      name { "Avocado Toast" }
      price { 999 }
      sku { "CAFE-BRK-001" }
      association :category, factory: [:category, :breakfast]
    end

    trait :breakfast_burrito do
      name { "Breakfast Burrito" }
      price { 899 }
      sku { "CAFE-BRK-002" }
      association :category, factory: [:category, :breakfast]
    end

    trait :acai_bowl do
      name { "Açaí Bowl" }
      price { 1199 }
      sku { "CAFE-BRK-003" }
      association :category, factory: [:category, :breakfast]
    end

    trait :yogurt_parfait do
      name { "Yogurt Parfait" }
      price { 699 }
      sku { "CAFE-BRK-004" }
      association :category, factory: [:category, :breakfast]
    end

    # ── Sandwiches ─────────────────────────────────────────────

    trait :turkey_club do
      name { "Turkey Club" }
      price { 1099 }
      sku { "CAFE-SAN-001" }
      association :category, factory: [:category, :sandwiches]
    end

    trait :caprese_panini do
      name { "Caprese Panini" }
      price { 999 }
      sku { "CAFE-SAN-002" }
      association :category, factory: [:category, :sandwiches]
    end

    trait :chicken_caesar_wrap do
      name { "Chicken Caesar Wrap" }
      price { 1049 }
      sku { "CAFE-SAN-003" }
      association :category, factory: [:category, :sandwiches]
    end

    trait :blt do
      name { "BLT" }
      price { 899 }
      sku { "CAFE-SAN-004" }
      association :category, factory: [:category, :sandwiches]
    end

    # ── Smoothies & Juices ─────────────────────────────────────

    trait :berry_blast_smoothie do
      name { "Berry Blast Smoothie" }
      price { 699 }
      sku { "CAFE-SMO-001" }
      association :category, factory: [:category, :smoothies]
    end

    trait :green_detox_juice do
      name { "Green Detox Juice" }
      price { 749 }
      sku { "CAFE-SMO-002" }
      association :category, factory: [:category, :smoothies]
    end

    trait :mango_tango_smoothie do
      name { "Mango Tango Smoothie" }
      price { 699 }
      sku { "CAFE-SMO-003" }
      association :category, factory: [:category, :smoothies]
    end

    trait :fresh_oj do
      name { "Fresh-Squeezed OJ" }
      price { 499 }
      sku { "CAFE-SMO-004" }
      association :category, factory: [:category, :smoothies]
    end

    # ═══════════════════════════════════════════════════════════
    #  BAR & NIGHTCLUB  (5 categories, 20 items)
    # ═══════════════════════════════════════════════════════════

    # ── Draft Beer ─────────────────────────────────────────────

    trait :house_lager do
      name { "House Lager" }
      price { 600 }
      sku { "BAR-DRF-001" }
      association :category, factory: [:category, :draft_beer]
    end

    trait :ipa do
      name { "IPA" }
      price { 700 }
      sku { "BAR-DRF-002" }
      association :category, factory: [:category, :draft_beer]
    end

    trait :stout do
      name { "Stout" }
      price { 750 }
      sku { "BAR-DRF-003" }
      association :category, factory: [:category, :draft_beer]
    end

    trait :wheat_beer do
      name { "Wheat Beer" }
      price { 650 }
      sku { "BAR-DRF-004" }
      association :category, factory: [:category, :draft_beer]
    end

    # ── Cocktails ──────────────────────────────────────────────

    trait :margarita do
      name { "Margarita" }
      price { 1200 }
      sku { "BAR-CTL-001" }
      association :category, factory: [:category, :cocktails]
    end

    trait :old_fashioned do
      name { "Old Fashioned" }
      price { 1400 }
      sku { "BAR-CTL-002" }
      association :category, factory: [:category, :cocktails]
    end

    trait :mojito do
      name { "Mojito" }
      price { 1300 }
      sku { "BAR-CTL-003" }
      association :category, factory: [:category, :cocktails]
    end

    trait :espresso_martini do
      name { "Espresso Martini" }
      price { 1500 }
      sku { "BAR-CTL-004" }
      association :category, factory: [:category, :cocktails]
    end

    # ── Spirits ────────────────────────────────────────────────

    trait :whiskey_neat do
      name { "Whiskey Neat" }
      price { 800 }
      sku { "BAR-SPR-001" }
      association :category, factory: [:category, :spirits]
    end

    trait :vodka_soda do
      name { "Vodka Soda" }
      price { 700 }
      sku { "BAR-SPR-002" }
      association :category, factory: [:category, :spirits]
    end

    trait :tequila_shot do
      name { "Tequila Shot" }
      price { 900 }
      sku { "BAR-SPR-003" }
      association :category, factory: [:category, :spirits]
    end

    trait :rum_and_coke do
      name { "Rum & Coke" }
      price { 800 }
      sku { "BAR-SPR-004" }
      association :category, factory: [:category, :spirits]
    end

    # ── Wine ───────────────────────────────────────────────────

    trait :house_red do
      name { "House Red (Glass)" }
      price { 1000 }
      sku { "BAR-WIN-001" }
      association :category, factory: [:category, :wine]
    end

    trait :house_white do
      name { "House White (Glass)" }
      price { 1000 }
      sku { "BAR-WIN-002" }
      association :category, factory: [:category, :wine]
    end

    trait :prosecco do
      name { "Prosecco (Glass)" }
      price { 1200 }
      sku { "BAR-WIN-003" }
      association :category, factory: [:category, :wine]
    end

    trait :rose do
      name { "Rosé (Glass)" }
      price { 1100 }
      sku { "BAR-WIN-004" }
      association :category, factory: [:category, :wine]
    end

    # ── Bar Snacks ─────────────────────────────────────────────

    trait :bar_loaded_fries do
      name { "Loaded Fries" }
      price { 999 }
      sku { "BAR-SNK-001" }
      association :category, factory: [:category, :bar_snacks]
    end

    trait :sliders do
      name { "Sliders (3pc)" }
      price { 1299 }
      sku { "BAR-SNK-002" }
      association :category, factory: [:category, :bar_snacks]
    end

    trait :bar_wings do
      name { "Chicken Wings" }
      price { 1199 }
      sku { "BAR-SNK-003" }
      association :category, factory: [:category, :bar_snacks]
    end

    trait :pretzel_bites do
      name { "Pretzel Bites" }
      price { 899 }
      sku { "BAR-SNK-004" }
      association :category, factory: [:category, :bar_snacks]
    end

    # ═══════════════════════════════════════════════════════════
    #  FOOD TRUCK  (3 categories, 14 items)
    # ═══════════════════════════════════════════════════════════

    # ── Tacos ──────────────────────────────────────────────────

    trait :carne_asada_taco do
      name { "Carne Asada Taco" }
      price { 499 }
      sku { "FT-TAC-001" }
      association :category, factory: [:category, :tacos]
    end

    trait :al_pastor_taco do
      name { "Al Pastor Taco" }
      price { 449 }
      sku { "FT-TAC-002" }
      association :category, factory: [:category, :tacos]
    end

    trait :fish_taco do
      name { "Fish Taco" }
      price { 549 }
      sku { "FT-TAC-003" }
      association :category, factory: [:category, :tacos]
    end

    trait :veggie_taco do
      name { "Veggie Taco" }
      price { 399 }
      sku { "FT-TAC-004" }
      association :category, factory: [:category, :tacos]
    end

    trait :birria_taco do
      name { "Birria Taco" }
      price { 599 }
      sku { "FT-TAC-005" }
      association :category, factory: [:category, :tacos]
    end

    # ── Burritos & Bowls ───────────────────────────────────────

    trait :classic_burrito do
      name { "Classic Burrito" }
      price { 1099 }
      sku { "FT-BUR-001" }
      association :category, factory: [:category, :burritos_bowls]
    end

    trait :burrito_bowl do
      name { "Burrito Bowl" }
      price { 1149 }
      sku { "FT-BUR-002" }
      association :category, factory: [:category, :burritos_bowls]
    end

    trait :quesadilla do
      name { "Quesadilla" }
      price { 899 }
      sku { "FT-BUR-003" }
      association :category, factory: [:category, :burritos_bowls]
    end

    trait :truck_nachos do
      name { "Loaded Nachos" }
      price { 999 }
      sku { "FT-BUR-004" }
      association :category, factory: [:category, :burritos_bowls]
    end

    # ── Sides & Drinks ─────────────────────────────────────────

    trait :chips_and_guac do
      name { "Chips & Guacamole" }
      price { 499 }
      sku { "FT-SDE-001" }
      association :category, factory: [:category, :truck_sides_drinks]
    end

    trait :elote do
      name { "Elote (Street Corn)" }
      price { 399 }
      sku { "FT-SDE-002" }
      association :category, factory: [:category, :truck_sides_drinks]
    end

    trait :rice_and_beans do
      name { "Rice & Beans" }
      price { 349 }
      sku { "FT-SDE-003" }
      association :category, factory: [:category, :truck_sides_drinks]
    end

    trait :horchata do
      name { "Horchata" }
      price { 399 }
      sku { "FT-SDE-004" }
      association :category, factory: [:category, :truck_sides_drinks]
    end

    trait :jarritos do
      name { "Jarritos" }
      price { 299 }
      sku { "FT-SDE-005" }
      association :category, factory: [:category, :truck_sides_drinks]
    end

    # ═══════════════════════════════════════════════════════════
    #  FINE DINING  (3 categories, 15 items)
    # ═══════════════════════════════════════════════════════════

    # ── First Course ───────────────────────────────────────────

    trait :seared_foie_gras do
      name { "Seared Foie Gras" }
      price { 2400 }
      sku { "FD-FST-001" }
      association :category, factory: [:category, :first_course]
    end

    trait :lobster_bisque do
      name { "Lobster Bisque" }
      price { 1800 }
      sku { "FD-FST-002" }
      association :category, factory: [:category, :first_course]
    end

    trait :tuna_tartare do
      name { "Tuna Tartare" }
      price { 2200 }
      sku { "FD-FST-003" }
      association :category, factory: [:category, :first_course]
    end

    trait :burrata_salad do
      name { "Burrata Salad" }
      price { 1900 }
      sku { "FD-FST-004" }
      association :category, factory: [:category, :first_course]
    end

    trait :oysters_half_dozen do
      name { "Oysters (Half Dozen)" }
      price { 2800 }
      sku { "FD-FST-005" }
      association :category, factory: [:category, :first_course]
    end

    # ── Main Course ────────────────────────────────────────────

    trait :wagyu_ribeye do
      name { "Wagyu Ribeye" }
      price { 6500 }
      sku { "FD-MAN-001" }
      association :category, factory: [:category, :main_course]
    end

    trait :chilean_sea_bass do
      name { "Pan-Seared Chilean Sea Bass" }
      price { 4800 }
      sku { "FD-MAN-002" }
      association :category, factory: [:category, :main_course]
    end

    trait :rack_of_lamb do
      name { "Rack of Lamb" }
      price { 5200 }
      sku { "FD-MAN-003" }
      association :category, factory: [:category, :main_course]
    end

    trait :duck_breast do
      name { "Duck Breast" }
      price { 4200 }
      sku { "FD-MAN-004" }
      association :category, factory: [:category, :main_course]
    end

    trait :truffle_risotto do
      name { "Truffle Risotto" }
      price { 3800 }
      sku { "FD-MAN-005" }
      association :category, factory: [:category, :main_course]
    end

    # ── Desserts & Petit Fours ─────────────────────────────────

    trait :creme_brulee do
      name { "Crème Brûlée" }
      price { 1600 }
      sku { "FD-DES-001" }
      association :category, factory: [:category, :fine_desserts]
    end

    trait :chocolate_souffle do
      name { "Chocolate Soufflé" }
      price { 1800 }
      sku { "FD-DES-002" }
      association :category, factory: [:category, :fine_desserts]
    end

    trait :tasting_plate do
      name { "Tasting Plate" }
      price { 2200 }
      sku { "FD-DES-003" }
      association :category, factory: [:category, :fine_desserts]
    end

    trait :cheese_board do
      name { "Cheese Board" }
      price { 2400 }
      sku { "FD-DES-004" }
      association :category, factory: [:category, :fine_desserts]
    end

    trait :fine_tiramisu do
      name { "Tiramisu" }
      price { 1600 }
      sku { "FD-DES-005" }
      association :category, factory: [:category, :fine_desserts]
    end

    # ═══════════════════════════════════════════════════════════
    #  PIZZERIA  (3 categories, 16 items)
    # ═══════════════════════════════════════════════════════════

    # ── Pizzas ─────────────────────────────────────────────────

    trait :margherita do
      name { "Margherita" }
      price { 1499 }
      sku { "PIZ-PIZ-001" }
      association :category, factory: [:category, :pizzas]
    end

    trait :pepperoni do
      name { "Pepperoni" }
      price { 1599 }
      sku { "PIZ-PIZ-002" }
      association :category, factory: [:category, :pizzas]
    end

    trait :supreme do
      name { "Supreme" }
      price { 1899 }
      sku { "PIZ-PIZ-003" }
      association :category, factory: [:category, :pizzas]
    end

    trait :hawaiian do
      name { "Hawaiian" }
      price { 1699 }
      sku { "PIZ-PIZ-004" }
      association :category, factory: [:category, :pizzas]
    end

    trait :bbq_chicken_pizza do
      name { "BBQ Chicken Pizza" }
      price { 1999 }
      sku { "PIZ-PIZ-005" }
      association :category, factory: [:category, :pizzas]
    end

    trait :meat_lovers do
      name { "Meat Lovers" }
      price { 2099 }
      sku { "PIZ-PIZ-006" }
      association :category, factory: [:category, :pizzas]
    end

    # ── Calzones & Stromboli ───────────────────────────────────

    trait :classic_calzone do
      name { "Classic Calzone" }
      price { 1399 }
      sku { "PIZ-CAL-001" }
      association :category, factory: [:category, :calzones]
    end

    trait :meat_calzone do
      name { "Meat Calzone" }
      price { 1599 }
      sku { "PIZ-CAL-002" }
      association :category, factory: [:category, :calzones]
    end

    trait :stromboli do
      name { "Stromboli" }
      price { 1499 }
      sku { "PIZ-CAL-003" }
      association :category, factory: [:category, :calzones]
    end

    trait :spinach_calzone do
      name { "Spinach & Ricotta Calzone" }
      price { 1399 }
      sku { "PIZ-CAL-004" }
      association :category, factory: [:category, :calzones]
    end

    # ── Sides & Drinks ─────────────────────────────────────────

    trait :garlic_bread do
      name { "Garlic Bread" }
      price { 599 }
      sku { "PIZ-SDE-001" }
      association :category, factory: [:category, :pizza_sides_drinks]
    end

    trait :garden_salad do
      name { "Garden Salad" }
      price { 799 }
      sku { "PIZ-SDE-002" }
      association :category, factory: [:category, :pizza_sides_drinks]
    end

    trait :caesar_salad do
      name { "Caesar Salad" }
      price { 899 }
      sku { "PIZ-SDE-003" }
      association :category, factory: [:category, :pizza_sides_drinks]
    end

    trait :garlic_knots do
      name { "Garlic Knots (6pc)" }
      price { 699 }
      sku { "PIZ-SDE-004" }
      association :category, factory: [:category, :pizza_sides_drinks]
    end

    trait :fountain_drink do
      name { "Fountain Drink" }
      price { 249 }
      sku { "PIZ-SDE-005" }
      association :category, factory: [:category, :pizza_sides_drinks]
    end

    trait :cannoli do
      name { "Cannoli" }
      price { 599 }
      sku { "PIZ-SDE-006" }
      association :category, factory: [:category, :pizza_sides_drinks]
    end

    # ═══════════════════════════════════════════════════════════
    #  RETAIL CLOTHING  (5 categories, 21 items)
    #  — items include `variants` jsonb with sizes/colors
    # ═══════════════════════════════════════════════════════════

    # ── Tops ───────────────────────────────────────────────────

    trait :classic_tshirt do
      name { "Classic T-Shirt" }
      price { 2499 }
      sku { "RCL-TOP-001" }
      association :category, factory: [:category, :tops]
      variants { [{ sizes: %w[S M L XL], colors: %w[Black White Navy] }] }
    end

    trait :button_down_shirt do
      name { "Button-Down Shirt" }
      price { 4999 }
      sku { "RCL-TOP-002" }
      association :category, factory: [:category, :tops]
      variants { [{ sizes: %w[S M L XL], colors: %w[White Blue Striped] }] }
    end

    trait :polo_shirt do
      name { "Polo Shirt" }
      price { 3999 }
      sku { "RCL-TOP-003" }
      association :category, factory: [:category, :tops]
      variants { [{ sizes: %w[S M L XL], colors: %w[Black White Red] }] }
    end

    trait :hoodie do
      name { "Hoodie" }
      price { 5499 }
      sku { "RCL-TOP-004" }
      association :category, factory: [:category, :tops]
      variants { [{ sizes: %w[S M L XL], colors: %w[Black Gray Navy] }] }
    end

    trait :tank_top do
      name { "Tank Top" }
      price { 1999 }
      sku { "RCL-TOP-005" }
      association :category, factory: [:category, :tops]
      variants { [{ sizes: %w[S M L XL], colors: %w[White Black] }] }
    end

    # ── Bottoms ────────────────────────────────────────────────

    trait :slim_fit_jeans do
      name { "Slim Fit Jeans" }
      price { 5999 }
      sku { "RCL-BTM-001" }
      association :category, factory: [:category, :bottoms]
      variants { [{ sizes: %w[28 30 32 34 36], colors: %w[Indigo Black Light] }] }
    end

    trait :chino_pants do
      name { "Chino Pants" }
      price { 4499 }
      sku { "RCL-BTM-002" }
      association :category, factory: [:category, :bottoms]
      variants { [{ sizes: %w[28 30 32 34 36], colors: %w[Khaki Navy Olive] }] }
    end

    trait :joggers do
      name { "Joggers" }
      price { 3999 }
      sku { "RCL-BTM-003" }
      association :category, factory: [:category, :bottoms]
      variants { [{ sizes: %w[S M L XL], colors: %w[Black Gray] }] }
    end

    trait :shorts do
      name { "Shorts" }
      price { 3499 }
      sku { "RCL-BTM-004" }
      association :category, factory: [:category, :bottoms]
      variants { [{ sizes: %w[S M L XL], colors: %w[Navy Khaki Black] }] }
    end

    # ── Outerwear ──────────────────────────────────────────────

    trait :denim_jacket do
      name { "Denim Jacket" }
      price { 7999 }
      sku { "RCL-OUT-001" }
      association :category, factory: [:category, :outerwear]
      variants { [{ sizes: %w[S M L XL], colors: %w[Indigo Light] }] }
    end

    trait :bomber_jacket do
      name { "Bomber Jacket" }
      price { 8999 }
      sku { "RCL-OUT-002" }
      association :category, factory: [:category, :outerwear]
      variants { [{ sizes: %w[S M L XL], colors: %w[Black Olive] }] }
    end

    trait :puffer_vest do
      name { "Puffer Vest" }
      price { 6999 }
      sku { "RCL-OUT-003" }
      association :category, factory: [:category, :outerwear]
      variants { [{ sizes: %w[S M L XL], colors: %w[Black Navy Red] }] }
    end

    trait :rain_jacket do
      name { "Rain Jacket" }
      price { 6499 }
      sku { "RCL-OUT-004" }
      association :category, factory: [:category, :outerwear]
      variants { [{ sizes: %w[S M L XL], colors: %w[Yellow Navy Black] }] }
    end

    # ── Accessories ────────────────────────────────────────────

    trait :baseball_cap do
      name { "Baseball Cap" }
      price { 2499 }
      sku { "RCL-ACC-001" }
      association :category, factory: [:category, :accessories]
      variants { [{ colors: %w[Black White Navy Red] }] }
    end

    trait :beanie do
      name { "Beanie" }
      price { 1999 }
      sku { "RCL-ACC-002" }
      association :category, factory: [:category, :accessories]
      variants { [{ colors: %w[Black Gray Burgundy] }] }
    end

    trait :canvas_belt do
      name { "Canvas Belt" }
      price { 2999 }
      sku { "RCL-ACC-003" }
      association :category, factory: [:category, :accessories]
      variants { [{ sizes: %w[S M L], colors: %w[Black Brown Tan] }] }
    end

    trait :scarf do
      name { "Scarf" }
      price { 3499 }
      sku { "RCL-ACC-004" }
      association :category, factory: [:category, :accessories]
      variants { [{ colors: %w[Plaid Solid\ Gray Solid\ Black] }] }
    end

    # ── Footwear ───────────────────────────────────────────────

    trait :canvas_sneakers do
      name { "Canvas Sneakers" }
      price { 4999 }
      sku { "RCL-FTW-001" }
      association :category, factory: [:category, :footwear]
      variants { [{ sizes: %w[7 8 9 10 11 12], colors: %w[White Black Navy] }] }
    end

    trait :leather_boots do
      name { "Leather Boots" }
      price { 12999 }
      sku { "RCL-FTW-002" }
      association :category, factory: [:category, :footwear]
      variants { [{ sizes: %w[7 8 9 10 11 12], colors: %w[Brown Black] }] }
    end

    trait :sandals do
      name { "Sandals" }
      price { 3499 }
      sku { "RCL-FTW-003" }
      association :category, factory: [:category, :footwear]
      variants { [{ sizes: %w[7 8 9 10 11 12], colors: %w[Tan Black] }] }
    end

    trait :running_shoes do
      name { "Running Shoes" }
      price { 8999 }
      sku { "RCL-FTW-004" }
      association :category, factory: [:category, :footwear]
      variants { [{ sizes: %w[7 8 9 10 11 12], colors: %w[Black White Red] }] }
    end

    # ═══════════════════════════════════════════════════════════
    #  RETAIL GENERAL  (5 categories, 20 items)
    # ═══════════════════════════════════════════════════════════

    # ── Electronics ────────────────────────────────────────────

    trait :wireless_earbuds do
      name { "Wireless Earbuds" }
      price { 7999 }
      sku { "RGN-ELC-001" }
      association :category, factory: [:category, :electronics]
    end

    trait :phone_charger do
      name { "Phone Charger" }
      price { 1999 }
      sku { "RGN-ELC-002" }
      association :category, factory: [:category, :electronics]
    end

    trait :bluetooth_speaker do
      name { "Bluetooth Speaker" }
      price { 4999 }
      sku { "RGN-ELC-003" }
      association :category, factory: [:category, :electronics]
    end

    trait :power_bank do
      name { "Power Bank" }
      price { 3499 }
      sku { "RGN-ELC-004" }
      association :category, factory: [:category, :electronics]
    end

    # ── Home & Kitchen ─────────────────────────────────────────

    trait :scented_candle do
      name { "Scented Candle" }
      price { 2499 }
      sku { "RGN-HMK-001" }
      association :category, factory: [:category, :home_kitchen]
    end

    trait :throw_pillow do
      name { "Throw Pillow" }
      price { 2999 }
      sku { "RGN-HMK-002" }
      association :category, factory: [:category, :home_kitchen]
    end

    trait :kitchen_towel_set do
      name { "Kitchen Towel Set" }
      price { 1499 }
      sku { "RGN-HMK-003" }
      association :category, factory: [:category, :home_kitchen]
    end

    trait :ceramic_mug do
      name { "Ceramic Mug" }
      price { 1299 }
      sku { "RGN-HMK-004" }
      association :category, factory: [:category, :home_kitchen]
    end

    # ── Personal Care ──────────────────────────────────────────

    trait :hand_soap do
      name { "Hand Soap" }
      price { 699 }
      sku { "RGN-PRC-001" }
      association :category, factory: [:category, :personal_care]
    end

    trait :body_lotion do
      name { "Body Lotion" }
      price { 1499 }
      sku { "RGN-PRC-002" }
      association :category, factory: [:category, :personal_care]
    end

    trait :lip_balm do
      name { "Lip Balm" }
      price { 499 }
      sku { "RGN-PRC-003" }
      association :category, factory: [:category, :personal_care]
    end

    trait :sunscreen do
      name { "Sunscreen SPF 50" }
      price { 1299 }
      sku { "RGN-PRC-004" }
      association :category, factory: [:category, :personal_care]
    end

    # ── Office Supplies ────────────────────────────────────────

    trait :notebook do
      name { "Notebook" }
      price { 999 }
      sku { "RGN-OFC-001" }
      association :category, factory: [:category, :office_supplies]
    end

    trait :pen_set do
      name { "Ballpoint Pen Set" }
      price { 799 }
      sku { "RGN-OFC-002" }
      association :category, factory: [:category, :office_supplies]
    end

    trait :desk_organizer do
      name { "Desk Organizer" }
      price { 1999 }
      sku { "RGN-OFC-003" }
      association :category, factory: [:category, :office_supplies]
    end

    trait :sticky_notes do
      name { "Sticky Notes" }
      price { 499 }
      sku { "RGN-OFC-004" }
      association :category, factory: [:category, :office_supplies]
    end

    # ── Snacks & Beverages ─────────────────────────────────────

    trait :granola_bar_3pack do
      name { "Granola Bar (3-Pack)" }
      price { 599 }
      sku { "RGN-SNK-001" }
      association :category, factory: [:category, :snacks_beverages]
    end

    trait :retail_sparkling_water do
      name { "Sparkling Water" }
      price { 249 }
      sku { "RGN-SNK-002" }
      association :category, factory: [:category, :snacks_beverages]
    end

    trait :trail_mix do
      name { "Trail Mix" }
      price { 699 }
      sku { "RGN-SNK-003" }
      association :category, factory: [:category, :snacks_beverages]
    end

    trait :dark_chocolate_bar do
      name { "Dark Chocolate Bar" }
      price { 499 }
      sku { "RGN-SNK-004" }
      association :category, factory: [:category, :snacks_beverages]
    end

    # ═══════════════════════════════════════════════════════════
    #  SALON & SPA  (4 categories, 16 items)
    #  — services use unit: "session", metadata with duration
    # ═══════════════════════════════════════════════════════════

    # ── Haircuts ───────────────────────────────────────────────

    trait :womens_haircut do
      name { "Women's Haircut" }
      price { 5500 }
      sku { "SPA-HAR-001" }
      unit { "session" }
      metadata { { "duration_minutes" => 45 } }
      association :category, factory: [:category, :haircuts]
    end

    trait :mens_haircut do
      name { "Men's Haircut" }
      price { 3000 }
      sku { "SPA-HAR-002" }
      unit { "session" }
      metadata { { "duration_minutes" => 30 } }
      association :category, factory: [:category, :haircuts]
    end

    trait :childrens_haircut do
      name { "Children's Haircut" }
      price { 2000 }
      sku { "SPA-HAR-003" }
      unit { "session" }
      metadata { { "duration_minutes" => 20 } }
      association :category, factory: [:category, :haircuts]
    end

    trait :bang_trim do
      name { "Bang Trim" }
      price { 1500 }
      sku { "SPA-HAR-004" }
      unit { "session" }
      metadata { { "duration_minutes" => 15 } }
      association :category, factory: [:category, :haircuts]
    end

    # ── Color Services ─────────────────────────────────────────

    trait :full_color do
      name { "Full Color" }
      price { 12000 }
      sku { "SPA-CLR-001" }
      unit { "session" }
      metadata { { "duration_minutes" => 120 } }
      association :category, factory: [:category, :color_services]
    end

    trait :partial_highlights do
      name { "Highlights (Partial)" }
      price { 9000 }
      sku { "SPA-CLR-002" }
      unit { "session" }
      metadata { { "duration_minutes" => 90 } }
      association :category, factory: [:category, :color_services]
    end

    trait :full_highlights do
      name { "Highlights (Full)" }
      price { 15000 }
      sku { "SPA-CLR-003" }
      unit { "session" }
      metadata { { "duration_minutes" => 120 } }
      association :category, factory: [:category, :color_services]
    end

    trait :balayage do
      name { "Balayage" }
      price { 18000 }
      sku { "SPA-CLR-004" }
      unit { "session" }
      metadata { { "duration_minutes" => 150 } }
      association :category, factory: [:category, :color_services]
    end

    # ── Spa Treatments ─────────────────────────────────────────

    trait :swedish_massage do
      name { "Swedish Massage (60min)" }
      price { 9500 }
      sku { "SPA-SPA-001" }
      unit { "hour" }
      metadata { { "duration_minutes" => 60 } }
      association :category, factory: [:category, :spa_treatments]
    end

    trait :deep_tissue_massage do
      name { "Deep Tissue Massage (60min)" }
      price { 11000 }
      sku { "SPA-SPA-002" }
      unit { "hour" }
      metadata { { "duration_minutes" => 60 } }
      association :category, factory: [:category, :spa_treatments]
    end

    trait :hot_stone_massage do
      name { "Hot Stone Massage (60min)" }
      price { 12000 }
      sku { "SPA-SPA-003" }
      unit { "hour" }
      metadata { { "duration_minutes" => 60 } }
      association :category, factory: [:category, :spa_treatments]
    end

    trait :facial do
      name { "Facial (60min)" }
      price { 8500 }
      sku { "SPA-SPA-004" }
      unit { "hour" }
      metadata { { "duration_minutes" => 60 } }
      association :category, factory: [:category, :spa_treatments]
    end

    # ── Nail Services ──────────────────────────────────────────

    trait :manicure do
      name { "Manicure" }
      price { 2500 }
      sku { "SPA-NAL-001" }
      unit { "session" }
      metadata { { "duration_minutes" => 30 } }
      association :category, factory: [:category, :nail_services]
    end

    trait :pedicure do
      name { "Pedicure" }
      price { 3500 }
      sku { "SPA-NAL-002" }
      unit { "session" }
      metadata { { "duration_minutes" => 45 } }
      association :category, factory: [:category, :nail_services]
    end

    trait :gel_manicure do
      name { "Gel Manicure" }
      price { 4000 }
      sku { "SPA-NAL-003" }
      unit { "session" }
      metadata { { "duration_minutes" => 45 } }
      association :category, factory: [:category, :nail_services]
    end

    trait :acrylic_full_set do
      name { "Acrylic Full Set" }
      price { 5500 }
      sku { "SPA-NAL-004" }
      unit { "session" }
      metadata { { "duration_minutes" => 60 } }
      association :category, factory: [:category, :nail_services]
    end
  end
end
