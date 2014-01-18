require 'nokogiri'
require 'vagrant/util/network_ip'

module VagrantPlugins
  module ProviderLibvirt
    module Util
      module LibvirtUtil
        include Vagrant::Util::NetworkIP

        # Return a list of all (active and inactive) libvirt networks as a list
        # of hashes with their name, network address and status (active or not)
        def libvirt_networks(libvirt_client)
          libvirt_networks = []

          active = libvirt_client.list_networks
          inactive = libvirt_client.list_defined_networks

          # Iterate over all (active and inactive) networks.
          active.concat(inactive).each do |network_name|
            libvirt_network = libvirt_client.lookup_network_by_name(
              network_name)

            # Parse ip address and netmask from the network xml description.
            xml = Nokogiri::XML(libvirt_network.xml_desc)
            ip = xml.xpath('/network/ip/@address').first
            ip = ip.value if ip
            netmask = xml.xpath('/network/ip/@netmask').first
            netmask = netmask.value if netmask

            if xml.at_xpath('//network/ip/dhcp')
              dhcp_enabled = true
            else
              dhcp_enabled = false
            end

            # Calculate network address of network from ip address and
            # netmask.
            if ip && netmask
              network_address = network_address(ip, netmask)
            else
              network_address = nil
            end

            libvirt_networks << {
              name:             network_name,
              ip_address:       ip,
              netmask:          netmask,
              network_address:  network_address,
              dhcp_enabled:     dhcp_enabled,
              bridge_name:      libvirt_network.bridge_name,
              created:          true,
              active:           libvirt_network.active?,
              autostart:        libvirt_network.autostart?,
              libvirt_network:  libvirt_network
            }
          end

          libvirt_networks
        end

      end
    end
  end
end
