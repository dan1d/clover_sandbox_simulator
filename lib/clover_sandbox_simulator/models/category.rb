# frozen_string_literal: true

module CloverSandboxSimulator
  module Models
    class Category < Record
      belongs_to :business_type
      has_many :items, dependent: :destroy

      # Validations — no uniqueness constraint; real Clover merchants
      # frequently have duplicate category names.
      validates :name, presence: true

      # Explicit sort scope (avoids default_scope anti-pattern)
      scope :sorted, -> { order(:sort_order) }
      scope :with_items, -> { joins(:items).distinct }
    end
  end
end
