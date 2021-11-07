# frozen_string_literal: true

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

Dir[File.dirname(__FILE__) + '/support/**/*.rb'].each { |f| require f }

RSpec.configure do |config|
  # ensure that setting of LIBVIRT_DEFAULT_URI in the environment is not picked
  # up directly by tests, instead they must set as needed. Some build envs will
  # may have it set to 'qemu:///session'.
  config.before(:suite) do
    ENV.delete('LIBVIRT_DEFAULT_URI')
  end

  config.mock_with :rspec do |mocks|
    # This option should be set when all dependencies are being loaded
    # before a spec run, as is the case in a typical spec helper. It will
    # cause any verifying double instantiation for a class that does not
    # exist to raise, protecting against incorrectly spelt names.
    mocks.verify_doubled_constant_names = true
  end
end
