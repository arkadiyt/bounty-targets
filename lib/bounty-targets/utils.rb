# frozen_string_literal: true

module BountyTargets
  module Retryable
    def retryable(tries = 10)
      yield
    rescue StandardError
      tries -= 1
      tries <= 0 ? raise : sleep(2) && retry
    end
  end
end
