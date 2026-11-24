# frozen_string_literal: true

require 'vagrant-spec/acceptance/configuration'
require "vagrant-spec/acceptance/rspec/matcher_exit_with"

require_relative 'isolated_environment'

# Exit code ssh uses to report that it could not establish the connection at
# all, which vagrant passes through. It is never the result of the commands
# run by the acceptance tests themselves.
SSH_CONNECTION_FAILED = 255

shared_context "acceptance" do
  # Setup the environment so that we have an isolated area
  # to run Vagrant. We do some configuration here as well in order
  # to replace "vagrant" with the proper path to Vagrant as well
  # as tell the isolated environment about custom environmental
  # variables to pass in.
  let!(:environment) { new_environment }

  let(:config) { Vagrant::Spec::Acceptance::Configuration.new }

  let(:extra_env) { {} }

  # The skeleton paths that will be used to configure environments.
  let(:skeleton_paths) do
    root = Vagrant::Spec.source_root.join("acceptance", "support-skeletons")
    config.skeleton_paths.dup.unshift(root)
  end

  after(:each) do |example|
    if example.exception.nil? || config.clean_on_fail
      environment.close
    else
      example.reporter.message("Temporary work and home dirs (#{environment.workdir} and #{environment.homedir}) not removed to allow debug")
    end
  end

  # Creates a new isolated environment instance each time it is called.
  #
  # @return [Acceptance::IsolatedEnvironment]
  def new_environment(env=nil)
    apps = { "vagrant" => config.vagrant_path }
    env  = config.env.merge(env || {})
    env.merge!(extra_env)

    VagrantPlugins::VagrantLibvirt::Spec::AcceptanceIsolatedEnvironment.new(
      apps: apps,
      env: env,
      skeleton_paths: skeleton_paths,
    )
  end

  # Executes the given command in the context of the isolated environment.
  #
  # @return [Object]
  def execute(*args, env: nil, log: true, &block)
    env ||= environment
    status("Execute: #{args.join(" ")}") if log
    env.execute(*args, &block)
  end

  # This method is an assertion helper for asserting that a process
  # succeeds. It is a wrapper around `execute` that asserts that the
  # exit status was successful.
  def assert_execute(*args, env: nil, &block)
    result = execute(*args, env: env, &block)
    expect(result).to exit_with(0)
    result
  end

  # Executes `vagrant ssh` in the isolated environment, retrying for as long
  # as ssh is unable to connect to the guest. A guest can be unreachable for
  # a short while after operations such as a snapshot restore, in which case
  # the example would otherwise fail on the connection error instead of on
  # the result of the command that was run.
  #
  # @return [Object] result of the last attempt
  def execute_ssh(*args, env: nil, attempts: 5, delay: 5, &block)
    result = nil

    attempts.times do |attempt|
      result = execute('vagrant', 'ssh', *args, env: env, &block)
      return result if result.exit_code != SSH_CONNECTION_FAILED
      break if attempt == attempts - 1

      status("ssh could not connect, retrying in #{delay}s (attempt #{attempt + 2}/#{attempts})")
      sleep(delay)
    end

    result
  end

  def status(message)
    RSpec.world.reporter.message(message)
  end
end
