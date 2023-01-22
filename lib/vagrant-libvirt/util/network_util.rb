# frozen_string_literal: true

require 'ipaddr'
require 'nokogiri'
require 'vagrant/util/network_ip'

class IPAddr
  def get_mask
    if @addr
      _to_string(@mask_addr)
    end
  end
end

module VagrantPlugins
  module ProviderLibvirt
    module Util
      module NetworkUtil
        include Vagrant::Util::NetworkIP

        def configured_networks(machine, logger)
          qemu_use_session = machine.provider_config.qemu_use_session
          qemu_use_agent = machine.provider_config.qemu_use_agent
          management_network_device = machine.provider_config.management_network_device
          management_network_name = machine.provider_config.management_network_name
          management_network_address = machine.provider_config.management_network_address
          management_network_mode = machine.provider_config.management_network_mode
          management_network_mac = machine.provider_config.management_network_mac
          management_network_guest_ipv6 = machine.provider_config.management_network_guest_ipv6
          management_network_autostart = machine.provider_config.management_network_autostart
          management_network_pci_bus = machine.provider_config.management_network_pci_bus
          management_network_pci_slot = machine.provider_config.management_network_pci_slot
          management_network_domain = machine.provider_config.management_network_domain
          management_network_mtu = machine.provider_config.management_network_mtu
          management_network_keep = machine.provider_config.management_network_keep
          management_network_driver_iommu = machine.provider_config.management_network_driver_iommu
          management_network_model_type = machine.provider_config.management_network_model_type
          logger.info "Using #{management_network_name} at #{management_network_address} as the management network #{management_network_mode} is the mode"

          begin
            management_network_ip = IPAddr.new(management_network_address)
          rescue ArgumentError
            raise Errors::ManagementNetworkError,
                  error_message: "#{management_network_address} is not a valid IP address"
          end

          # capture address into $1 and mask into $2
          management_network_ip.inspect =~ /IPv4:(.*)\/(.*)>/

          if Regexp.last_match(2) == '255.255.255.255'
            raise Errors::ManagementNetworkError,
                  error_message: "#{management_network_address} does not include both an address and subnet mask"
          end

          if qemu_use_session
            management_network_options = {
              iface_type: :public_network,
              model_type: management_network_model_type,
              dev: management_network_device,
              mode: 'bridge',
              type: 'bridge',
              bus: management_network_pci_bus,
              slot: management_network_pci_slot
            }
          else
            management_network_options = {
              iface_type: :private_network,
              model_type: management_network_model_type,
              network_name: management_network_name,
              ip: Regexp.last_match(1),
              netmask: Regexp.last_match(2),
              dhcp_enabled: true,
              forward_mode: management_network_mode,
              guest_ipv6: management_network_guest_ipv6,
              autostart: management_network_autostart,
              bus: management_network_pci_bus,
              slot: management_network_pci_slot
            }
          end

          management_network_options[:driver_iommu] = management_network_driver_iommu

          unless management_network_mac.nil?
            management_network_options[:mac] = management_network_mac
          end

          unless management_network_domain.nil?
            management_network_options[:domain_name] = management_network_domain
          end

          unless management_network_mtu.nil?
            management_network_options[:mtu] = management_network_mtu
          end

          unless management_network_pci_bus.nil? and management_network_pci_slot.nil?
            management_network_options[:bus] = management_network_pci_bus
            management_network_options[:slot] = management_network_pci_slot
          end

          if management_network_keep
            management_network_options[:always_destroy] = false
          end

          # if there is a box and management network is disabled
          # need qemu agent enabled and at least one network that can be accessed
          if (
            machine.config.vm.box &&
            !machine.provider_config.mgmt_attach &&
            !machine.provider_config.qemu_use_agent &&
            !machine.config.vm.networks.any? { |type, _| ["private_network", "public_network"].include?(type.to_s) }
          )
            raise Errors::ManagementNetworkRequired
          end

          # add management network to list of networks to check
          # unless mgmt_attach set to false
          networks = if machine.provider_config.mgmt_attach
                       [management_network_options]
                     else
                       []
                     end

          machine.config.vm.networks.each do |type, original_options|
            logger.debug "In config found network type #{type} options #{original_options}"
            # Options can be specified in Vagrantfile in short format (:ip => ...),
            # or provider format # (:libvirt__network_name => ...).
            # https://github.com/mitchellh/vagrant/blob/main/lib/vagrant/util/scoped_hash_override.rb
            options = scoped_hash_override(original_options, :libvirt)
            # store type in options
            # use default values if not already set
            options = {
              iface_type:   type,
              netmask:      options[:network_address] ?
                            IPAddr.new(options[:network_address]).get_mask :
                            '255.255.255.0',
              dhcp_enabled: true,
              forward_mode: 'nat',
              always_destroy: true
            }.merge(options)

            if options[:type].to_s == 'dhcp' && options[:ip].nil?
              options[:network_name] = options[:network_name] ?
                                       options[:network_name] :
                                       'vagrant-private-dhcp'
            end

            # add to list of networks to check
            networks.push(options)
          end

          networks
        end

        # Return a list of all (active and inactive) Libvirt networks as a list
        # of hashes with their name, network address and status (active or not)
        def libvirt_networks(driver)
          libvirt_networks = []

          # Iterate over all (active and inactive) networks.
          driver.list_all_networks.each do |libvirt_network|

            # Parse ip address and netmask from the network xml description.
            xml = Nokogiri::XML(libvirt_network.xml_desc)
            ip = xml.xpath('/network/ip/@address').first
            ip = ip.value if ip
            netmask = xml.xpath('/network/ip/@netmask').first
            netmask = netmask.value if netmask

            dhcp_enabled = if xml.at_xpath('//network/ip/dhcp')
                             true
                           else
                             false
                           end

            domain_name = xml.at_xpath('/network/domain/@name')
            domain_name = domain_name.value if domain_name

            # Calculate network address of network from ip address and
            # netmask.
            network_address = (network_address(ip, netmask) if ip && netmask)

            libvirt_networks << {
              name:             libvirt_network.name,
              ip_address:       ip,
              netmask:          netmask,
              network_address:  network_address,
              dhcp_enabled:     dhcp_enabled,
              bridge_name:      libvirt_network.bridge_name,
              domain_name:      domain_name,
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
