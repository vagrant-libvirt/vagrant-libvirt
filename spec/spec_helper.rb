# frozen_string_literal: true

# make simplecov optional
begin
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
rescue LoadError
  TRUTHY_VALUES = %w(t true yes y 1).freeze
  require_simplecov = ENV.fetch('VAGRANT_LIBVIRT_REQUIRE_SIMPLECOV', 'false').to_s.downcase
  if TRUTHY_VALUES.include?(require_simplecov)
    raise
  end
end


require 'vagrant-libvirt'
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
    mocks.verify_partial_doubles = true
  end

  # don't run acceptance tests by default
  config.filter_run_excluding :acceptance => true
end
