# frozen_string_literal: true

require_relative '../spec_helper'

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
  let(:iso_env)          { test_env.create_vagrant_env ui_class: Vagrant::UI::Basic }
  let(:machine)          { iso_env.machine(:test, :libvirt) }
  let(:ui)               { Vagrant::UI::Silent.new }
  let(:env)              { { env: iso_env, machine: machine, ui: ui, root_path: '/rootpath' } }

  # Mock the communicator to prevent SSH commands for being executed.
  let(:communicator)     { double('communicator') }
  let(:app)              { ->(env) {} }

  before (:each) do
    allow(machine).to receive(:communicate).and_return(communicator)
    allow(machine).to receive(:ui).and_return(ui)
  end

  around do |example|
    Dir.mktmpdir do |tmpdir|
      original_home = ENV['HOME']

      begin
        virtual_home = File.expand_path(File.join(tmpdir, 'home'))
        Dir.mkdir(virtual_home)
        ENV['HOME'] = virtual_home

        example.run
      ensure
        ENV['HOME'] = original_home
      end
    end
  end
end
