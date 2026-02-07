# frozen_string_literal: true

module CloverSandboxSimulator
  module Models
    class BusinessType < Record
      has_many :categories, dependent: :destroy
      has_many :items, through: :categories
      has_many :simulated_orders, dependent: :nullify

      # Validations
      validates :key, presence: true, uniqueness: true
      validates :name, presence: true

      # Scopes by industry
      scope :food_types, -> { where(industry: "food") }
      scope :retail_types, -> { where(industry: "retail") }
      scope :service_types, -> { where(industry: "service") }

      # Find by key (the primary lookup pattern)
      def self.find_by_key!(key)
        find_by!(key: key)
      end
    end
  end
end
