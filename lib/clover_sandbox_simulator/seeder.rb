# frozen_string_literal: true

require "factory_bot"

module CloverSandboxSimulator
  # Seeds the database with realistic Clover sandbox data using FactoryBot factories.
  #
  # Idempotent — safe to run multiple times without creating duplicates.
  # Uses `find_or_create_by!` on unique keys (BusinessType.key,
  # Category.name+business_type, Item.name+category).
  #
  # @example Seed all business types
  #   CloverSandboxSimulator::Seeder.seed!
  #
  # @example Seed a single business type
  #   CloverSandboxSimulator::Seeder.seed!(business_type: :retail_clothing)
  #
  class Seeder
    # Maps each business type trait to its category traits,
    # and each category trait to its item traits.
    #
    # Structure: { bt_trait => { cat_trait => [item_traits] } }
    SEED_MAP = {
      restaurant: {
        appetizers: %i[buffalo_wings mozzarella_sticks loaded_nachos spinach_artichoke_dip calamari],
        entrees: %i[grilled_salmon ny_strip_steak chicken_parmesan pasta_primavera herb_roasted_chicken],
        sides: %i[french_fries coleslaw mashed_potatoes side_salad onion_rings],
        desserts: %i[chocolate_lava_cake ny_cheesecake restaurant_tiramisu apple_pie ice_cream_sundae],
        beverages: %i[soft_drink iced_tea lemonade sparkling_water restaurant_coffee]
      },
      cafe_bakery: {
        coffee_espresso: %i[house_drip_coffee espresso cappuccino latte cold_brew],
        pastries: %i[croissant blueberry_muffin cinnamon_roll chocolate_chip_cookie],
        breakfast: %i[avocado_toast breakfast_burrito acai_bowl yogurt_parfait],
        sandwiches: %i[turkey_club caprese_panini chicken_caesar_wrap blt],
        smoothies: %i[berry_blast_smoothie green_detox_juice mango_tango_smoothie fresh_oj]
      },
      bar_nightclub: {
        draft_beer: %i[house_lager ipa stout wheat_beer],
        cocktails: %i[margarita old_fashioned mojito espresso_martini],
        spirits: %i[whiskey_neat vodka_soda tequila_shot rum_and_coke],
        wine: %i[house_red house_white prosecco rose],
        bar_snacks: %i[bar_loaded_fries sliders bar_wings pretzel_bites]
      },
      food_truck: {
        tacos: %i[carne_asada_taco al_pastor_taco fish_taco veggie_taco birria_taco],
        burritos_bowls: %i[classic_burrito burrito_bowl quesadilla truck_nachos],
        truck_sides_drinks: %i[chips_and_guac elote rice_and_beans horchata jarritos]
      },
      fine_dining: {
        first_course: %i[seared_foie_gras lobster_bisque tuna_tartare burrata_salad oysters_half_dozen],
        main_course: %i[wagyu_ribeye chilean_sea_bass rack_of_lamb duck_breast truffle_risotto],
        fine_desserts: %i[creme_brulee chocolate_souffle tasting_plate cheese_board fine_tiramisu]
      },
      pizzeria: {
        pizzas: %i[margherita pepperoni supreme hawaiian bbq_chicken_pizza meat_lovers],
        calzones: %i[classic_calzone meat_calzone stromboli spinach_calzone],
        pizza_sides_drinks: %i[garlic_bread garden_salad caesar_salad garlic_knots fountain_drink cannoli]
      },
      retail_clothing: {
        tops: %i[classic_tshirt button_down_shirt polo_shirt hoodie tank_top],
        bottoms: %i[slim_fit_jeans chino_pants joggers shorts],
        outerwear: %i[denim_jacket bomber_jacket puffer_vest rain_jacket],
        accessories: %i[baseball_cap beanie canvas_belt scarf],
        footwear: %i[canvas_sneakers leather_boots sandals running_shoes]
      },
      retail_general: {
        electronics: %i[wireless_earbuds phone_charger bluetooth_speaker power_bank],
        home_kitchen: %i[scented_candle throw_pillow kitchen_towel_set ceramic_mug],
        personal_care: %i[hand_soap body_lotion lip_balm sunscreen],
        office_supplies: %i[notebook pen_set desk_organizer sticky_notes],
        snacks_beverages: %i[granola_bar_3pack retail_sparkling_water trail_mix dark_chocolate_bar]
      },
      salon_spa: {
        haircuts: %i[womens_haircut mens_haircut childrens_haircut bang_trim],
        color_services: %i[full_color partial_highlights full_highlights balayage],
        spa_treatments: %i[swedish_massage deep_tissue_massage hot_stone_massage facial],
        nail_services: %i[manicure pedicure gel_manicure acrylic_full_set]
      }
    }.freeze

    # Expected category counts per business type (for spec validation).
    CATEGORY_COUNTS = SEED_MAP.transform_values { |cats| cats.size }.freeze

    # Expected item counts per category (for spec validation).
    ITEM_COUNTS = SEED_MAP.each_with_object({}) do |(_, cats), hash|
      cats.each { |cat_trait, items| hash[cat_trait] = items.size }
    end.freeze

    # Seed all (or one) business types with categories and items.
    #
    # @param business_type [Symbol, String, nil] Seed only this type, or all if nil.
    # @return [Hash] Summary of created/found counts.
    def self.seed!(business_type: nil)
      new.seed!(business_type: business_type)
    end

    # @param business_type [Symbol, String, nil]
    # @return [Hash] Summary with :business_types, :categories, :items counts.
    def seed!(business_type: nil)
      types_to_seed = resolve_types(business_type)

      counts = { business_types: 0, categories: 0, items: 0 }

      types_to_seed.each do |bt_trait, categories_map|
        bt = seed_business_type(bt_trait)
        counts[:business_types] += 1

        categories_map.each do |cat_trait, item_traits|
          cat = seed_category(cat_trait, bt)
          counts[:categories] += 1

          item_traits.each do |item_trait|
            seed_item(item_trait, cat)
            counts[:items] += 1
          end
        end
      end

      CloverSandboxSimulator.logger.info(
        "Seeding complete: #{counts[:business_types]} business types, " \
        "#{counts[:categories]} categories, #{counts[:items]} items"
      )

      counts
    end

    private

    # Resolve which business types to seed.
    #
    # @param business_type [Symbol, String, nil]
    # @return [Hash] subset of SEED_MAP
    # @raise [ArgumentError] if the business type is unknown
    def resolve_types(business_type)
      return SEED_MAP if business_type.nil?

      key = business_type.to_sym
      unless SEED_MAP.key?(key)
        raise ArgumentError,
              "Unknown business type: #{key}. Valid types: #{SEED_MAP.keys.join(', ')}"
      end

      { key => SEED_MAP[key] }
    end

    # Find or create a business type using factory attributes.
    #
    # @param trait [Symbol]
    # @return [Models::BusinessType]
    def seed_business_type(trait)
      attrs = FactoryBot.attributes_for(:business_type, trait)
      Models::BusinessType.find_or_create_by!(key: attrs[:key]) do |bt|
        bt.assign_attributes(attrs)
      end
    end

    # Find or create a category using factory attributes.
    #
    # @param trait [Symbol]
    # @param business_type [Models::BusinessType]
    # @return [Models::Category]
    def seed_category(trait, business_type)
      attrs = FactoryBot.attributes_for(:category, trait)
      Models::Category.find_or_create_by!(name: attrs[:name], business_type: business_type) do |cat|
        cat.assign_attributes(attrs.except(:business_type_id))
      end
    end

    # Find or create an item using factory attributes.
    #
    # @param trait [Symbol]
    # @param category [Models::Category]
    # @return [Models::Item]
    def seed_item(trait, category)
      attrs = FactoryBot.attributes_for(:item, trait)
      Models::Item.find_or_create_by!(name: attrs[:name], category: category) do |item|
        item.assign_attributes(attrs.except(:category_id))
      end
    end
  end
end
