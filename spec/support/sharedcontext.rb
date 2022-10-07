# frozen_string_literal: true

require 'spec_helper'

shared_context 'unit' do
  include_context 'vagrant-unit'

  let(:vagrantfile_providerconfig) { '' }
  let(:vagrantfile) do
    <<-EOF
    Vagrant.configure('2') do |config|
      config.vm.box = "vagrant-libvirt/test"
      config.vm.define :test
      config.vm.provider :libvirt do |libvirt|
        #{vagrantfile_providerconfig}
      end
    end
    EOF
  end
  let(:test_env) do
    test_env = isolated_environment
    test_env.vagrantfile vagrantfile
    test_env
  end
  let(:env)              { { env: iso_env, machine: machine, ui: ui, root_path: '/rootpath' } }
  let(:conf)             { Vagrant::Config::V2::DummyConfig.new }
  let(:ui)               { Vagrant::UI::Silent.new }
  let(:iso_env)          { test_env.create_vagrant_env ui_class: Vagrant::UI::Basic }
  let(:machine)          { iso_env.machine(:test, :libvirt) }
  # Mock the communicator to prevent SSH commands for being executed.
  let(:communicator)     { double('communicator') }
  # Mock the guest operating system.
  let(:guest)            { double('guest') }
  let(:app)              { ->(env) {} }
  let(:plugin)           { register_plugin }

  before (:each) do
    allow(machine).to receive(:guest).and_return(guest)
    allow(machine).to receive(:communicate).and_return(communicator)
    allow(machine).to receive(:ui).and_return(ui)
  end
end
