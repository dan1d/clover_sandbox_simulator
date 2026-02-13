# frozen_string_literal: true

module CloverSandboxSimulator
  module Models
    class Item < Record
      belongs_to :category

      # Validations — no uniqueness constraint; real Clover merchants
      # can have items with the same name in the same category.
      validates :name, presence: true
      validates :price, presence: true,
                        numericality: { only_integer: true, greater_than_or_equal_to: 0 }

      # Scopes
      scope :active, -> { where(active: true) }
      scope :inactive, -> { where(active: false) }

      scope :for_business_type, ->(key) {
        joins(category: :business_type)
          .where(business_types: { key: key })
      }

      scope :in_category, ->(category_name) {
        joins(:category).where(categories: { name: category_name })
      }

      # Price in dollars (convenience)
      def price_dollars
        (price || 0) / 100.0
      end
    end
  end
end
