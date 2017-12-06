# frozen_string_literal: true

module BountyTargets
  class ERBContext
    def initialize(hash = {})
      hash.each do |key, value|
        instance_variable_set("@#{key}", value)
      end
    end

    def bind
      binding
    end
  end
end
