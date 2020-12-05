require 'simplecov'
SimpleCov.start do
  enable_coverage :branch
  add_filter 'spec/'
end

require 'vagrant-libvirt'
require 'support/environment_helper'
require 'vagrant-spec/unit'

RSpec.configure do |spec|
end
