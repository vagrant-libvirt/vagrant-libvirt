# frozen_string_literal: true

require 'fog/libvirt/requests/compute/dhcp_leases'

require 'spec_helper'
require 'support/binding_proc'
require 'support/sharedcontext'

require 'vagrant-libvirt/driver'

describe VagrantPlugins::ProviderLibvirt::Driver do
  include_context 'unit'
  include_context 'libvirt'

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

  # make it easier for distros that want to switch the default value for
  # qemu_use_session to true by ensuring it is explicitly false for tests.
  before do
    allow(machine.provider_config).to receive(:qemu_use_session).and_return(false)
    allow(logger).to receive(:info)
    allow(logger).to receive(:debug)
    allow(machine.provider).to receive('driver').and_call_original
    allow(machine2.provider).to receive('driver').and_call_original
  end

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
      expect(Libvirt).to receive(:open_read_only).with('qemu+ssh://user@remote1/system').and_return(system_connection1)
      expect(Libvirt).to receive(:open_read_only).with('qemu+ssh://vms@remote2/system').and_return(system_connection2)

      expect(machine.provider.driver.system_connection).to eq(system_connection1)
      expect(machine2.provider.driver.system_connection).to eq(system_connection2)
    end

    it 'should configure the connection once' do
      expect(Libvirt).to receive(:open_read_only).with('qemu+ssh://user@remote1/system').and_return(system_connection1)

      expect(machine.provider.driver.system_connection).to eq(system_connection1)
      expect(machine.provider.driver.system_connection).to eq(system_connection1)
      expect(machine.provider.driver.system_connection).to eq(system_connection1)
    end
  end

  describe '#get_ipaddress' do
    context 'when domain exists' do
      # not used yet, but this is the form that is returned from addresses
      let(:addresses) { {
        :public => ["192.168.122.111"],
        :private => ["192.168.122.111"],
      } }

      before do
        allow(subject).to receive(:get_domain).and_return(domain)
      end

      it 'should retrieve the address via domain fog-libvirt API' do
        # ideally should be able to yield a block to wait_for and check that
        # the 'addresses' function on the domain is called correctly.
        expect(domain).to receive(:wait_for).and_return(nil)
        expect(subject.get_ipaddress).to eq(nil)
      end

      context 'when qemu_use_agent is enabled' do
        let(:qemu_agent_interfaces) {
          <<-EOF
          {
            "return": [
              {
                "name": "lo",
                "ip-addresses": [
                  {
                    "ip-address-type": "ipv4",
                    "ip-address": "127.0.0.1",
                    "prefix": 8
                  }
                ],
                "hardware-address": "00:00:00:00:00:00"
              },
              {
                "name": "eth0",
                "ip-addresses": [
                  {
                    "ip-address-type": "ipv4",
                    "ip-address": "192.168.122.42",
                    "prefix": 24
                  }
                ],
                "hardware-address": "52:54:00:f8:67:98"
              }
            ]
          }
          EOF
        }

        before do
          allow(machine.provider_config).to receive(:qemu_use_agent).and_return(true)
        end

        it 'should retrieve the address via the agent' do
          expect(subject).to receive(:connection).and_return(connection)
          expect(libvirt_client).to receive(:lookup_domain_by_uuid).and_return(libvirt_domain)
          expect(libvirt_domain).to receive(:qemu_agent_command).and_return(qemu_agent_interfaces)
          expect(domain).to receive(:mac).and_return("52:54:00:f8:67:98").exactly(2).times

          expect(subject.get_ipaddress).to eq("192.168.122.42")
        end

        context 'when qemu_use_session is enabled' do
          before do
            allow(machine.provider_config).to receive(:qemu_use_session).and_return(true)
          end

          it 'should still retrieve the address via the agent' do
            expect(subject).to receive(:connection).and_return(connection)
            expect(libvirt_client).to receive(:lookup_domain_by_uuid).and_return(libvirt_domain)
            expect(libvirt_domain).to receive(:qemu_agent_command).and_return(qemu_agent_interfaces)
            expect(domain).to receive(:mac).and_return("52:54:00:f8:67:98").exactly(2).times

            expect(subject.get_ipaddress).to eq("192.168.122.42")
          end
        end
      end

      context 'when qemu_use_session is enabled' do
        let(:networks) { [instance_double(::Fog::Libvirt::Compute::Real)] }
        let(:dhcp_leases) {
          {
            "iface"      =>"virbr0",
            "expirytime" =>1636287162,
            "type"       =>0,
            "mac"        =>"52:54:00:8b:dc:5f",
            "ipaddr"     =>"192.168.122.43",
            "prefix"     =>24,
            "hostname"   =>"vagrant-default_test",
            "clientid"   =>"ff:00:8b:dc:5f:00:01:00:01:29:1a:65:42:52:54:00:8b:dc:5f",
          }
        }

        before do
          allow(machine.provider_config).to receive(:qemu_use_session).and_return(true)
        end

        it 'should retrieve the address via the system dhcp-leases API' do
          expect(domain).to receive(:mac).and_return("52:54:00:8b:dc:5f")
          expect(subject).to receive(:system_connection).and_return(system_connection1)
          expect(system_connection1).to receive(:list_all_networks).and_return(networks)
          expect(networks[0]).to receive(:dhcp_leases).and_return([dhcp_leases])

          expect(subject.get_ipaddress).to eq("192.168.122.43")
        end

        context 'when qemu_use_agent is enabled' do
          before do
            allow(machine.provider_config).to receive(:qemu_use_agent).and_return(true)
          end

          it 'should retrieve the address via the agent' do
            expect(subject).to receive(:get_ipaddress_from_qemu_agent).and_return("192.168.122.44")

            expect(subject.get_ipaddress).to eq("192.168.122.44")
          end
        end
      end
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
        nil,
        :unknown,
        {
          :setup => ProcWithBinding.new do
            expect(domain).to receive(:state).and_return('unknown').at_least(:once)
          end,
        }
      ],
      [
        'terminated',
        :not_created,
        {
          :setup => ProcWithBinding.new do
            expect(domain).to receive(:state).and_return('terminated').at_least(:once)
          end,
        }
      ],
      [
        'no IP returned',
        :inaccessible,
        {
          :setup => ProcWithBinding.new do
            expect(domain).to receive(:state).and_return('running').at_least(:once)
            expect(subject).to receive(:get_ipaddress).and_raise(Fog::Errors::TimeoutError)
          end,
        }
      ],
      [
        'running',
        :running,
        {
          :setup => ProcWithBinding.new do
            expect(domain).to receive(:state).and_return('running').at_least(:once)
            expect(subject).to receive(:get_ipaddress).and_return('192.168.121.2')
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

        expect(subject.state).to eq(expected)
      end
    end
  end
end
