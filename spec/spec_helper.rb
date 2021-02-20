require 'simplecov'
require 'simplecov-lcov'

# patch simplecov configuration
if ! SimpleCov::Configuration.method_defined? :branch_coverage?
  module SimpleCov
    module Configuration
      def branch_coverage?
        return false
      end
    end
  end
end

SimpleCov::Formatter::LcovFormatter.config do |config|
  config.report_with_single_file = true
  config.single_report_path = 'coverage/lcov.info'
end

SimpleCov.formatters = SimpleCov::Formatter::MultiFormatter.new(
  [
    SimpleCov::Formatter::HTMLFormatter,
    SimpleCov::Formatter::LcovFormatter,
  ]
)
SimpleCov.start do
  add_filter 'spec/'
end

require 'vagrant-libvirt'
require 'support/environment_helper'
require 'vagrant-spec/unit'

RSpec.configure do |spec|
end
