# frozen_string_literal: true

require_relative '../../spec_helper'

require 'vagrant-libvirt/util/network_util'

describe 'VagrantPlugins::ProviderLibvirt::Util::NetworkUtil' do
  include_context 'libvirt'

  subject do
    Class.new do
      include VagrantPlugins::ProviderLibvirt::Util::NetworkUtil

      def initialize
        @logger = Log4r::Logger.new('test-logger')
      end
    end.new
  end

  def create_libvirt_network(name, attrs = {})
    default_attrs = {
      active?: true,
      autostart?: true
    }
    network_xml = File.read(File.join(File.dirname(__FILE__), File.basename(__FILE__, '.rb'), "#{name}.xml"))
    double = instance_double(::Libvirt::Network)
    allow(double).to receive(:xml_desc).and_return(network_xml)
    allow(double).to receive(:name).and_return(name)

    xml = REXML::Document.new(network_xml)
    bridge = REXML::XPath.first(xml, '/network/bridge')
    default_attrs[:bridge_name] =
      !bridge.nil? ? bridge.attributes['name'] : Libvirt::Error.new("network #{name} does not have attribute bridge_name")

    default_attrs.merge(attrs).each do |aname, avalue|
      if avalue.is_a?(Exception)
        allow(double).to receive(aname).and_raise(avalue)
      else
        allow(double).to receive(aname).and_return(avalue)
      end
    end

    double
  end

  describe '#libvirt_networks' do
    let(:default_network) { create_libvirt_network('default') }
    let(:additional_network) { create_libvirt_network('vagrant-libvirt') }

    it 'should retrieve the list of networks' do
      expect(logger).to_not receive(:debug)
      expect(driver).to receive(:list_all_networks).and_return([default_network, additional_network])

      expect(subject.libvirt_networks(driver)).to match_array(
        [
          hash_including(name: 'default'),
          hash_including(name: 'vagrant-libvirt')
        ]
      )
    end
  end

  describe '#network_interfaces' do
    let(:configured_networks_all) do
      [
        {
          iface_type: :private_network,
          ip: '192.168.121.0',
          netmask: '255.255.255.0',
          network_name: 'vagrant-libvirt',
        },
        {
          auto_correct: true,
          iface_type: :forwarded_port,
        },
        {
          iface_type: :private_network,
          ip: '192.168.123.0',
          netmask: '255.255.255.0',
          network_name: 'vagrant-libvirt-1',
        },
        {
          iface_type: :private_network,
          ip: '192.168.124.0',
          netmask: '255.255.255.0',
          network_name: 'vagrant-libvirt-2',
        },
      ]
    end
    let(:configured_networks) do
      [
        configured_networks_all[0]
      ]
    end

    before do
      expect(subject).to receive(:configured_networks).with(machine, logger).and_return(configured_networks)
    end

    it 'should return a list of default adapters configured' do
      expect(logger).to receive(:debug).with('Adapter not specified so found slot 0')
      expect(logger).to receive(:debug).with('Found network by name')

      expect(subject.network_interfaces(machine, logger)).to match_array([configured_networks[0]])
    end

    context 'with forwarded ports' do
      let(:configured_networks) do
        [
          configured_networks_all[0],
          configured_networks_all[1]
        ]
      end

      it 'should skip the forwarded port' do
        expect(logger).to receive(:debug).with('Adapter not specified so found slot 0')
        expect(logger).to receive(:debug).with('Found network by name')

        expect(subject.network_interfaces(machine, logger)).to match_array([configured_networks[0]])
      end
    end

    context 'with 2 additional private networks with adapter set' do
      let(:configured_networks) do
        [
          configured_networks_all[0],
          configured_networks_all[2].merge(:adapter => 2),
          configured_networks_all[3],
        ]
      end

      it 'should return the first private network last' do
        expect(logger).to receive(:debug).with('Adapter not specified so found slot 0')
        expect(logger).to receive(:debug).with('Found network by name').exactly(3).times
        expect(logger).to receive(:debug).with('Using specified adapter slot 2')
        expect(logger).to receive(:debug).with('Adapter not specified so found slot 1')

        expect(subject.network_interfaces(machine, logger)).to match_array(
          [
            configured_networks[0],
            configured_networks[2],
            configured_networks[1]
          ]
        )
      end
    end
  end

  describe '#configured_networks' do
    it 'should return a list of default adapters configured' do
      expect(logger).to receive(:info).with('Using vagrant-libvirt at 192.168.121.0/24 as the management network nat is the mode')
      expect(logger).to receive(:debug).with(/In config found network type forwarded_port options/)

      expect(subject.configured_networks(machine, logger)).to match_array(
        [
          hash_including(
            {
              forward_mode: 'nat',
              iface_type: :private_network,
              ip: '192.168.121.0',
              model_type: 'virtio',
              netmask: '255.255.255.0',
              network_name: 'vagrant-libvirt',
            }
          ),
          hash_including(
            {
              auto_correct: true,
              forward_mode: 'nat',
              guest: 22,
              host: 2222,
              host_ip: '127.0.0.1',
              id: 'ssh',
              iface_type: :forwarded_port,
              netmask: '255.255.255.0',
              protocol: 'tcp',
            }
          )
        ]
      )
    end
  end
end
