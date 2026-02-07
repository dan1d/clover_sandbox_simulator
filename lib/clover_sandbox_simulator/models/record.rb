# frozen_string_literal: true

require "active_record"

module CloverSandboxSimulator
  module Models
    # Shared base class for all simulator ActiveRecord models.
    #
    # Equivalent to ApplicationRecord in Rails, but for standalone usage.
    # All models inherit from this so we can add shared behaviour
    # (e.g. logging, default scopes) in one place.
    class Record < ::ActiveRecord::Base
      self.abstract_class = true
    end
  end
end
