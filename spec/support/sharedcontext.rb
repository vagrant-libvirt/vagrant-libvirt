require 'spec_helper'

shared_context "unit" do
  include_context 'vagrant-unit'

  let(:vagrantfile) do <<-EOF
    Vagrant.configure('2') do |config|
      config.vm.define :test
    end
    EOF
  end
  let(:test_env) do
    test_env = isolated_environment
    test_env.vagrantfile vagrantfile
    test_env
  end
  let(:env)              { { env: iso_env, machine: machine, ui: ui, root_path: '/rootpath' } }
  let(:conf)             { Vagrant::Config::V2::DummyConfig.new() }
  let(:ui)               { Vagrant::UI::Basic.new() }
  let(:iso_env)          { test_env.create_vagrant_env ui_class: Vagrant::UI::Basic }
  let(:machine)          { iso_env.machine(:test, :libvirt) }
  # Mock the communicator to prevent SSH commands for being executed.
  let(:communicator)     { double('communicator') }
  # Mock the guest operating system.
  let(:guest)            { double('guest') }
  let(:app)              { lambda { |env| } }
  let(:plugin)           { register_plugin() }

  before (:each) do
    machine.stub(:guest => guest)
    machine.stub(:communicator => communicator)
    machine.stub(:id => id)
  end

end
