# frozen_string_literal: true

require_relative '../../spec_helper'

require 'vagrant-libvirt/util/network_util'

describe 'VagrantPlugins::ProviderLibvirt::Util::NetworkUtil' do
  include_context 'libvirt'

  subject do
    Class.new {
      include VagrantPlugins::ProviderLibvirt::Util::NetworkUtil

      def initialize
        @logger = Log4r::Logger.new('test-logger')
      end
    }.new
  end

  def create_libvirt_network(name, attrs={})
    default_attrs = {
      :active? => true,
      :autostart? => true,
    }
    network_xml = File.read(File.join(File.dirname(__FILE__), File.basename(__FILE__, '.rb'), name + '.xml'))
    double = instance_double(::Libvirt::Network)
    allow(double).to receive(:xml_desc).and_return(network_xml)
    allow(double).to receive(:name).and_return(name)

    xml = REXML::Document.new(network_xml)
    bridge = REXML::XPath.first(xml, '/network/bridge')
    default_attrs[:bridge_name] = !bridge.nil? ? bridge.attributes['name'] : Libvirt::Error.new("network #{name} does not have attribute bridge_name")

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

      expect(subject.libvirt_networks(driver)).to match_array([
        hash_including(:name => 'default'),
        hash_including(:name => 'vagrant-libvirt'),
      ])
    end
  end
end
