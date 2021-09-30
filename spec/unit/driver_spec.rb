# frozen_string_literal: true

require 'spec_helper'
require 'support/binding_proc'
require 'support/sharedcontext'

require 'vagrant-libvirt/driver'

describe VagrantPlugins::ProviderLibvirt::Driver do
  include_context 'unit'

  subject { described_class.new(machine) }

  let(:vagrantfile) do
    <<-EOF
    Vagrant.configure('2') do |config|
      config.vm.define :test1 do |node|
        node.vm.provider :libvirt do |domain|
          domain.uri = "qemu+ssh://user@remote1/system"
        end
      end
      config.vm.define :test2 do |node|
        node.vm.provider :libvirt do |domain|
          domain.uri = "qemu+ssh://vms@remote2/system"
        end
      end
    end
    EOF
  end
  # need to override the default package iso_env as using a different
  # name for the test machines above.
  let(:machine)    { iso_env.machine(:test1, :libvirt) }
  let(:machine2)   { iso_env.machine(:test2, :libvirt) }
  let(:connection1) { double("connection 1") } 
  let(:connection2) { double("connection 2") } 
  let(:system_connection1) { double("system connection 1") } 
  let(:system_connection2) { double("system connection 2") } 

  describe '#connection' do
    it 'should configure a separate connection per machine' do
      expect(Fog::Compute).to receive(:new).with(
        hash_including({:libvirt_uri => 'qemu+ssh://user@remote1/system'})).and_return(connection1)
      expect(Fog::Compute).to receive(:new).with(
        hash_including({:libvirt_uri => 'qemu+ssh://vms@remote2/system'})).and_return(connection2)

      expect(machine.provider.driver.connection).to eq(connection1)
      expect(machine2.provider.driver.connection).to eq(connection2)
    end

    it 'should configure the connection once' do
      expect(Fog::Compute).to receive(:new).once().and_return(connection1)

      expect(machine.provider.driver.connection).to eq(connection1)
      expect(machine.provider.driver.connection).to eq(connection1)
      expect(machine.provider.driver.connection).to eq(connection1)
    end
  end

  describe '#system_connection' do
    # note that the urls for the two tests are currently
    # incorrect here as they should be the following:
    #   qemu+ssh://user@remote1/system
    #   qemu+ssh://vms@remote2/system
    #
    # In that the system uri should be resolved based on
    # the provider uri so that for:
    #   uri => qemu+ssh://user@remote1/session
    # system_uri should be 'qemu+ssh://user@remote1/system'
    # and not 'qemu:///system'.
    it 'should configure a separate connection per machine' do
      expect(Libvirt).to receive(:open).with('qemu:///system').and_return(system_connection1)
      expect(Libvirt).to receive(:open).with('qemu:///system').and_return(system_connection2)

      expect(machine.provider.driver.system_connection).to eq(system_connection1)
      expect(machine2.provider.driver.system_connection).to eq(system_connection2)
    end

    it 'should configure the connection once' do
      expect(Libvirt).to receive(:open).with('qemu:///system').and_return(system_connection1)

      expect(machine.provider.driver.system_connection).to eq(system_connection1)
      expect(machine.provider.driver.system_connection).to eq(system_connection1)
      expect(machine.provider.driver.system_connection).to eq(system_connection1)
    end
  end

  describe '#state' do
    let(:domain) { double('domain') }

    before do
      allow(subject).to receive(:get_domain).and_return(domain)
    end

    [
      [
        'not found',
        :not_created,
        {
          :setup => ProcWithBinding.new do
            expect(subject).to receive(:get_domain).and_return(nil)
          end,
        }
      ],
      [
        'libvirt error',
        :not_created,
        {
          :setup => ProcWithBinding.new do
            expect(subject).to receive(:get_domain).and_raise(Libvirt::RetrieveError, 'missing')
          end,
        }
      ],
      [
        'terminated',
        :not_created,
        {
          :setup => ProcWithBinding.new do
            expect(domain).to receive(:state).and_return('terminated')
          end,
        }
      ],
      [
        'no IP returned',
        :inaccessible,
        {
          :setup => ProcWithBinding.new do
            expect(domain).to receive(:state).and_return('running').twice()
            expect(subject).to receive(:get_domain_ipaddress).and_raise(Fog::Errors::TimeoutError)
          end,
        }
      ],
      [
        'running',
        :running,
        {
          :setup => ProcWithBinding.new do
            expect(domain).to receive(:state).and_return('running').twice()
            expect(subject).to receive(:get_domain_ipaddress).and_return('192.168.121.2')
          end,
        }
      ],
    ].each do |name, expected, options|
      opts = {}
      opts.merge!(options) if options

      it "should handle '#{name}' by returning '#{expected}'" do
        if !opts[:setup].nil?
          opts[:setup].apply_binding(binding)
        end

        expect(subject.state(machine)).to eq(expected)
      end
    end
  end
end
