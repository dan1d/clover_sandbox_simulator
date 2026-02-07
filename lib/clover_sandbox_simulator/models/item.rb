# frozen_string_literal: true

module CloverSandboxSimulator
  module Models
    class Item < Record
      belongs_to :category

      # Validations
      validates :name, presence: true,
                       uniqueness: { scope: :category_id }
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
        price / 100.0
      end
    end
  end
end
