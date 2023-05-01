# frozen_string_literal: true

require_relative '../../spec_helper'

require 'vagrant-libvirt/errors'
require 'vagrant-libvirt/action/create_network_interfaces'
require 'vagrant-libvirt/util/unindent'

describe VagrantPlugins::ProviderLibvirt::Action::CreateNetworkInterfaces do
  subject { described_class.new(app, env) }

  include_context 'unit'
  include_context 'libvirt'

  let(:networks) { [
    instance_double(::Libvirt::Network),
    instance_double(::Libvirt::Network),
  ] }
  let(:default_network_xml) {
    <<-EOF
    <network>
      <name>default</name>
      <uuid>e5f871eb-2899-48b2-83df-78aa43efa360</uuid>
      <forward mode='nat'>
        <nat>
          <port start='1024' end='65535'/>
        </nat>
      </forward>
      <bridge name='virbr0' stp='on' delay='0'/>
      <mac address='52:54:00:71:ce:a6'/>
      <ip address='192.168.122.1' netmask='255.255.255.0'>
        <dhcp>
          <range start='192.168.122.2' end='192.168.122.254'/>
        </dhcp>
      </ip>
    </network>
    EOF
  }
  let(:management_network_xml) {
    <<-EOF
    <network ipv6='yes'>
      <name>vagrant-libvirt</name>
      <uuid>46360938-0607-4168-a182-1352fac4a4f9</uuid>
      <forward mode='nat'/>
      <bridge name='virbr1' stp='on' delay='0'/>
      <mac address='52:54:00:c2:d5:a5'/>
      <ip address='192.168.121.1' netmask='255.255.255.0'>
        <dhcp>
          <range start='192.168.121.1' end='192.168.121.254'/>
        </dhcp>
      </ip>
    </network>
    EOF
  }
  let(:default_management_nic_xml) {
    <<-EOF.unindent
    <interface type="network">
      <alias name="ua-net-0"></alias>
      <source network="vagrant-libvirt"></source>
      <target dev="vnet0"></target>
      <model type="virtio"></model>
      <driver iommu="off"></driver>
    </interface>
    EOF
  }

  before do
    allow(app).to receive(:call)
    allow(libvirt_client).to receive(:lookup_domain_by_uuid).and_return(libvirt_domain)

    allow(driver).to receive(:list_all_networks).and_return(networks)

    allow(networks[0]).to receive(:xml_desc).and_return(default_network_xml)
    allow(networks[0]).to receive(:name).and_return('default')
    allow(networks[0]).to receive(:bridge_name).and_return('virbr0')
    allow(networks[0]).to receive(:active?).and_return(true)
    allow(networks[0]).to receive(:autostart?).and_return(true)
    allow(networks[1]).to receive(:xml_desc).and_return(management_network_xml)
    allow(networks[1]).to receive(:name).and_return('vagrant-libvirt')
    allow(networks[1]).to receive(:bridge_name).and_return('virbr1')
    allow(networks[1]).to receive(:active?).and_return(true)
    allow(networks[1]).to receive(:autostart?).and_return(false)

    allow(logger).to receive(:info)
    allow(logger).to receive(:debug)
  end

  describe '#call' do
    it 'should inject the management network definition' do
      expect(driver).to receive(:attach_device).with(default_management_nic_xml)

      expect(subject.call(env)).to be_nil
    end

    context 'management network' do
      let(:domain_xml) {
        # don't need full domain here, just enough for the network element to work
        <<-EOF.unindent
        <domain type='qemu'>
          <devices>
            <interface type='network'>
              <alias name='ua-net-0'/>
              <mac address='52:54:00:7d:14:0e'/>
              <source network='vagrant-libvirt'/>
              <target dev="myvnet0"></target>
              <model type='virtio'/>
              <driver iommu='off'/>
              <address type='pci' domain='0x0000' bus='0x00' slot='0x05' function='0x0'/>
            </interface>
          </devices>
        </domain>
        EOF
      }

      before do
        allow(libvirt_domain).to receive(:xml_desc).and_return(domain_xml)
      end

      context 'when iface name is set' do
        let(:vagrantfile_providerconfig) {
          <<-EOF
          libvirt.management_network_iface_name = 'myvnet0'
          EOF
        }
        let(:management_nic_xml) {
          <<-EOF.unindent
          <interface type="network">
            <alias name="ua-net-0"></alias>
            <source network="vagrant-libvirt"></source>
            <target dev="myvnet0"></target>
            <model type="virtio"></model>
            <driver iommu="off"></driver>
          </interface>
          EOF
        }

        it 'should set target appropriately' do
          expect(driver).to receive(:attach_device).with(management_nic_xml)

          expect(subject.call(env)).to be_nil
        end
      end
    end

    context 'private network' do
      let(:vagrantfile) do
        <<-EOF
        Vagrant.configure('2') do |config|
          config.vm.box = "vagrant-libvirt/test"
          config.vm.define :test
          config.vm.provider :libvirt do |libvirt|
            #{vagrantfile_providerconfig}
          end

          config.vm.network :private_network, :ip => "10.20.30.40"
        end
        EOF
      end
      let(:private_network) { instance_double(::Libvirt::Network) }
      let(:private_network_xml) {
        <<-EOF
        <network ipv6='yes'>
          <name>test1</name>
          <uuid>46360938-0607-4168-a182-1352fac4a4f9</uuid>
          <forward mode='nat'/>
          <bridge name='virbr2' stp='on' delay='0'/>
          <mac address='52:54:00:c2:d5:a5'/>
          <ip address='10.20.30.1' netmask='255.255.255.0'>
            <dhcp>
              <range start='10.20.30.1' end='10.20.30.254'/>
            </dhcp>
          </ip>
        </network>
        EOF
      }
      let(:private_nic_xml) {
        <<-EOF.unindent
        <interface type="network">
          <alias name="ua-net-1"></alias>
          <source network="test1"></source>
          <target dev="vnet1"></target>
          <model type="virtio"></model>
          <driver iommu="off"></driver>
        </interface>
        EOF
      }

      before do
        allow(private_network).to receive(:xml_desc).and_return(private_network_xml)
        allow(private_network).to receive(:name).and_return('test1')
        allow(private_network).to receive(:bridge_name).and_return('virbr2')
        allow(private_network).to receive(:active?).and_return(true)
        allow(private_network).to receive(:autostart?).and_return(false)
      end

      it 'should attach for two networks' do
        expect(driver).to receive(:list_all_networks).and_return(networks + [private_network])
        expect(driver).to receive(:attach_device).with(default_management_nic_xml)
        expect(driver).to receive(:attach_device).with(private_nic_xml)
        expect(guest).to receive(:capability).with(:configure_networks, any_args)

        expect(subject.call(env)).to be_nil
      end

      context 'when iface name is set' do
        let(:private_nic_xml) {
          <<-EOF.unindent
          <interface type="network">
            <alias name="ua-net-1"></alias>
            <source network="test1"></source>
            <target dev="myvnet0"></target>
            <model type="virtio"></model>
            <driver iommu="off"></driver>
          </interface>
          EOF
        }

        before do
          machine.config.vm.networks[0][1][:libvirt__iface_name] = "myvnet0"
        end

        it 'should set target appropriately' do
          expect(driver).to receive(:list_all_networks).and_return(networks + [private_network])
          expect(driver).to receive(:attach_device).with(default_management_nic_xml)
          expect(driver).to receive(:attach_device).with(private_nic_xml)
          expect(guest).to receive(:capability).with(:configure_networks, any_args)

          expect(subject.call(env)).to be_nil
        end
      end

      it 'should skip configuring networks in guest without box' do
        machine.config.vm.box = nil

        expect(driver).to receive(:list_all_networks).and_return(networks + [private_network])
        expect(driver).to receive(:attach_device).with(default_management_nic_xml)
        expect(driver).to receive(:attach_device).with(private_nic_xml)
        expect(guest).to_not receive(:capability).with(:configure_networks, any_args)

        expect(subject.call(env)).to be_nil
      end
    end

    context 'public network' do
      let(:vagrantfile) do
        <<-EOF
        Vagrant.configure('2') do |config|
          config.vm.box = "vagrant-libvirt/test"
          config.vm.define :test
          config.vm.provider :libvirt do |libvirt|
            #{vagrantfile_providerconfig}
          end

          config.vm.network :public_network, :dev => "virbr1", :mode => "bridge", :type => "bridge"
        end
        EOF
      end
      let(:public_network) { instance_double(::Libvirt::Network) }
      let(:public_network_xml) {
        <<-EOF
        <network ipv6='yes'>
          <name>test1</name>
          <uuid>46360938-0607-4168-a182-1352fac4a4f9</uuid>
          <forward mode='nat'/>
          <bridge name='virbr2' stp='on' delay='0'/>
          <mac address='52:54:00:c2:d5:a5'/>
          <ip address='10.20.30.1' netmask='255.255.255.0'>
            <dhcp>
              <range start='10.20.30.1' end='10.20.30.254'/>
            </dhcp>
          </ip>
        </network>
        EOF
      }
      let(:public_nic_xml) {
        <<-EOF.unindent
        <interface type='bridge'>
          <alias name='ua-net-1'/>
          <source bridge='virbr1'/>
          <model type='virtio'/>
        </interface>
        EOF
      }
      let(:domain_xml) {
        # don't need full domain here, just enough for the network element to work
        <<-EOF.unindent
        <domain type='qemu'>
          <devices>
            <interface type='network'>
              <alias name='ua-net-0'/>
              <mac address='52:54:00:7d:14:0e'/>
              <source network='vagrant-libvirt'/>
              <model type='virtio'/>
              <driver iommu='off'/>
              <address type='pci' domain='0x0000' bus='0x00' slot='0x05' function='0x0'/>
            </interface>
            <interface type='network'>
              <alias name='ua-net-1'/>
              <mac address='52:54:00:7d:14:0f'/>
              <source bridge='virbr1'/>
              <model type='virtio'/>
              <address type='pci' domain='0x0000' bus='0x00' slot='0x06' function='0x0'/>
            </interface>
          </devices>
        </domain>
        EOF
      }

      before do
        allow(public_network).to receive(:xml_desc).and_return(public_network_xml)
        allow(public_network).to receive(:name).and_return('test1')
        allow(public_network).to receive(:bridge_name).and_return('virbr2')
        allow(public_network).to receive(:active?).and_return(true)
        allow(public_network).to receive(:autostart?).and_return(false)

        allow(libvirt_domain).to receive(:xml_desc).and_return(domain_xml)
      end

      it 'should attach for two networks' do
        expect(driver).to receive(:list_all_networks).and_return(networks + [public_network])
        expect(driver).to receive(:attach_device).with(default_management_nic_xml)
        expect(driver).to receive(:attach_device).with(public_nic_xml)
        expect(guest).to receive(:capability).with(:configure_networks, any_args)

        expect(subject.call(env)).to be_nil
      end

      context 'when iface name is set' do
        let(:public_nic_xml) {
          <<-EOF.unindent
          <interface type='bridge'>
            <alias name='ua-net-1'/>
            <source bridge='virbr1'/>
            <target dev='myvnet0'/>
            <model type='virtio'/>
          </interface>
          EOF
        }

        before do
          machine.config.vm.networks[0][1][:libvirt__iface_name] = "myvnet0"
        end

        it 'should set target appropriately' do
          expect(driver).to receive(:list_all_networks).and_return(networks + [public_network])
          expect(driver).to receive(:attach_device).with(default_management_nic_xml)
          expect(driver).to receive(:attach_device).with(public_nic_xml)
          expect(guest).to receive(:capability).with(:configure_networks, any_args)

          expect(subject.call(env)).to be_nil
        end
      end
    end
  end
end
