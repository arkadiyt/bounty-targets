# frozen_string_literal: true

require 'coveralls'
Coveralls.wear!
ENV['COVERALLS_NOISY'] = '1'
require 'webmock/rspec'
require 'bounty-targets'

Object.class_eval do
  def self.make_all_methods_public!
    private_instance_methods.each(&method(:public))
    protected_instance_methods.each(&method(:public))
  end
end
