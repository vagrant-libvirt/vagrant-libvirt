# frozen_string_literal: true

require 'vagrant-spec/acceptance/configuration'
require "vagrant-spec/acceptance/rspec/matcher_exit_with"

require_relative 'isolated_environment'

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

  def status(message)
    RSpec.world.reporter.message(message)
  end
end
