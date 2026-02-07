# frozen_string_literal: true

module CloverSandboxSimulator
  module Models
    class Category < Record
      belongs_to :business_type
      has_many :items, dependent: :destroy

      # Validations
      validates :name, presence: true,
                       uniqueness: { scope: :business_type_id }

      # Default ordering
      default_scope { order(:sort_order) }

      scope :with_items, -> { joins(:items).distinct }
    end
  end
end
