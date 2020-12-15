require 'simplecov'
require 'coveralls'

SimpleCov.formatter = Coveralls::SimpleCov::Formatter
SimpleCov.start do
  enable_coverage :branch if Gem::Version.new(RUBY_VERSION) >= Gem::Version.new('2.5')
  add_filter 'spec/'
end

require 'vagrant-libvirt'
require 'support/environment_helper'
require 'vagrant-spec/unit'

RSpec.configure do |spec|
end
