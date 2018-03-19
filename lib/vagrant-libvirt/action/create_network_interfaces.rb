require 'log4r'
require 'vagrant/util/network_ip'
require 'vagrant/util/scoped_hash_override'

module VagrantPlugins
  module ProviderLibvirt
    module Action
      # Create network interfaces for domain, before domain is running.
      # Networks for connecting those interfaces should be already prepared.
      class CreateNetworkInterfaces
        include VagrantPlugins::ProviderLibvirt::Util::ErbTemplate
        include VagrantPlugins::ProviderLibvirt::Util::NetworkUtil
        include Vagrant::Util::NetworkIP
        include Vagrant::Util::ScopedHashOverride

        def initialize(app, env)
          @logger = Log4r::Logger.new('vagrant_libvirt::action::create_network_interfaces')
          @management_network_name = env[:machine].provider_config.management_network_name
          config = env[:machine].provider_config
          @nic_model_type = config.nic_model_type || 'virtio'
          @nic_adapter_count = config.nic_adapter_count
          @app = app
        end

        def call(env)
          # Get domain first.
          begin
            domain = env[:machine].provider.driver.connection.client.lookup_domain_by_uuid(
              env[:machine].id.to_s
            )
          rescue => e
            raise Errors::NoDomainError,
                  error_message: e.message
          end

          # Setup list of interfaces before creating them.
          adapters = []

          # Vagrant gives you adapter 0 by default
          # Assign interfaces to slots.
          configured_networks(env, @logger).each do |options|
            # dont need to create interface for this type
            next if options[:iface_type] == :forwarded_port

            # TODO: fill first ifaces with adapter option specified.
            if options[:adapter]
              if adapters[options[:adapter]]
                raise Errors::InterfaceSlotNotAvailable
              end

              free_slot = options[:adapter].to_i
              @logger.debug "Using specified adapter slot #{free_slot}"
            else
              free_slot = find_empty(adapters)
              @logger.debug "Adapter not specified so found slot #{free_slot}"
              raise Errors::InterfaceSlotExhausted if free_slot.nil?
            end

            # We have slot for interface, fill it with interface configuration.
            adapters[free_slot] = options
            adapters[free_slot][:network_name] = interface_network(
              env[:machine].provider.driver.connection.client, adapters[free_slot]
            )
          end

          # Create each interface as new domain device.
          @macs_per_network = Hash.new(0)
          adapters.each_with_index do |iface_configuration, slot_number|
            @iface_number = slot_number
            @network_name = iface_configuration[:network_name]
            @source_options = {
              network: @network_name
            }
            @mac = iface_configuration.fetch(:mac, false)
            @model_type = iface_configuration.fetch(:model_type, @nic_model_type)
            @driver_name = iface_configuration.fetch(:driver_name, false)
            @driver_queues = iface_configuration.fetch(:driver_queues, false)
            @device_name = iface_configuration.fetch(:iface_name, false)
            @mtu = iface_configuration.fetch(:mtu, nil)
            @pci_bus = iface_configuration.fetch(:bus, nil)
            @pci_slot = iface_configuration.fetch(:slot, nil)
            template_name = 'interface'
            @type = nil
            @udp_tunnel = nil
            # Configuration for public interfaces which use the macvtap driver
            if iface_configuration[:iface_type] == :public_network
              @device = iface_configuration.fetch(:dev, 'eth0')
              @mode = iface_configuration.fetch(:mode, 'bridge')
              @type = iface_configuration.fetch(:type, 'direct')
              @model_type = iface_configuration.fetch(:model_type, @nic_model_type)
              @driver_name = iface_configuration.fetch(:driver_name, false)
              @driver_queues = iface_configuration.fetch(:driver_queues, false)
              @portgroup = iface_configuration.fetch(:portgroup, nil)
              @network_name = iface_configuration.fetch(:network_name, @network_name)
              template_name = 'public_interface'
              @logger.info("Setting up public interface using device #{@device} in mode #{@mode}")
              @ovs = iface_configuration.fetch(:ovs, false)
              @trust_guest_rx_filters = iface_configuration.fetch(:trust_guest_rx_filters, false)
            # configuration for udp or tcp tunnel interfaces (p2p conn btwn guest OSes)
            elsif iface_configuration.fetch(:tunnel_type, nil)
              @type = iface_configuration.fetch(:tunnel_type)
              @tunnel_port = iface_configuration.fetch(:tunnel_port, nil)
              raise Errors::TunnelPortNotDefined if @tunnel_port.nil?
              if @type == 'udp'
                # default udp tunnel source to 127.0.0.1
                @udp_tunnel={
                  address: iface_configuration.fetch(:tunnel_local_ip,'127.0.0.1'),
                  port: iface_configuration.fetch(:tunnel_local_port)
                }
              end
              # default mcast tunnel to 239.255.1.1. Web search says this
              # 239.255.x.x is a safe range to use for general use mcast
              default_ip = if @type == 'mcast'
                             '239.255.1.1'
                           else
                             '127.0.0.1'
                           end
              @source_options = {
                address: iface_configuration.fetch(:tunnel_ip, default_ip),
                port: @tunnel_port
              }
              @tunnel_type = iface_configuration.fetch(:model_type, @nic_model_type)
              @driver_name = iface_configuration.fetch(:driver_name, false)
              @driver_queues = iface_configuration.fetch(:driver_queues, false)
              template_name = 'tunnel_interface'
              @logger.info("Setting up #{@type} tunnel interface using  #{@tunnel_ip} port #{@tunnel_port}")
            end

            message = "Creating network interface eth#{@iface_number}"
            message << " connected to network #{@network_name}."
            if @mac
              @mac = @mac.scan(/(\h{2})/).join(':')
              message << " Using MAC address: #{@mac}"
            end
            @logger.info(message)

            begin
              # FIXME: all options for network driver should be hash from Vagrantfile
              driver_options = {}
              driver_options[:name] = @driver_name if @driver_name
              driver_options[:queues] = @driver_queues if @driver_queues
              @udp_tunnel ||= {}
              xml = if template_name == 'interface' or
                       template_name == 'tunnel_interface'
                      interface_xml(@type,
                                    @source_options,
                                    @mac,
                                    @device_name,
                                    @iface_number,
                                    @model_type,
                                    @mtu,
                                    driver_options,
                                    @udp_tunnel,
                                    @pci_bus,
                                    @pci_slot)
                    else
                      to_xml(template_name)
                    end
              domain.attach_device(xml)
            rescue => e
              raise Errors::AttachDeviceError,
                    error_message: e.message
            end

            # Re-read the network configuration and grab the MAC address
            if iface_configuration[:iface_type] == :public_network
              xml = Nokogiri::XML(domain.xml_desc)
              source = "@network='#{@network_name}'"
              if @type == 'direct'
                  source = "@dev='#{@device}'"
              elsif @portgroup.nil?
                source = "@bridge='#{@device}'"
              end
              if not @mac
                macs = xml.xpath("/domain/devices/interface[source[#{source}]]/mac/@address")
                @mac = macs[@macs_per_network[source]]
                iface_configuration[:mac] = @mac.to_s
              end
              @macs_per_network[source] += 1
            end
          end

          # Continue the middleware chain.
          @app.call(env)

          if env[:machine].config.vm.box
            # Configure interfaces that user requested. Machine should be up and
            # running now.
            networks_to_configure = []

            adapters.each_with_index do |options, slot_number|
              # Skip configuring the management network, which is on the first interface.
              # It's used for provisioning and it has to be available during provisioning,
              # ifdown command is not acceptable here.
              next if slot_number.zero?
              next if options[:auto_config] === false
              @logger.debug "Configuring interface slot_number #{slot_number} options #{options}"

              network = {
                interface: slot_number,
                use_dhcp_assigned_default_route: options[:use_dhcp_assigned_default_route],
                mac_address: options[:mac]
              }

              if options[:ip]
                network = {
                  type: :static,
                  ip: options[:ip],
                  netmask: options[:netmask],
                  gateway: options[:gateway]
                }.merge(network)
              else
                network[:type] = :dhcp
              end

              # do not run configure_networks for tcp tunnel interfaces
              next if options.fetch(:tunnel_type, nil)

              networks_to_configure << network
            end

            env[:ui].info I18n.t('vagrant.actions.vm.network.configuring')
            env[:machine].guest.capability(
              :configure_networks, networks_to_configure
            )

          end
        end

        private

        def target_dev_name(device_name, type, iface_number)
          if device_name
            device_name
          elsif type == 'network'
            "vnet#{iface_number}"
          else
            # TODO can we use same name vnet#ifnum?
            #"tnet#{iface_number}" FIXME plugin vagrant-libvirt trying to create second tnet0 interface
            "vnet#{iface_number}"
          end
        end

        def interface_xml(type, source_options, mac, device_name,
                          iface_number, model_type, mtu, driver_options,
                          udp_tunnel={}, pci_bus, pci_slot)
          Nokogiri::XML::Builder.new do |xml|
            xml.interface(type: type || 'network') do
              xml.source(source_options) do
                xml.local(udp_tunnel) if type == 'udp'
              end
              xml.mac(address: mac) if mac
              xml.target(dev: target_dev_name(device_name, type, iface_number))
              xml.alias(name: "net#{iface_number}")
              xml.model(type: model_type.to_s)
              xml.mtu(size: Integer(mtu)) if mtu
              xml.driver(driver_options)
              xml.address(type: 'pci', bus: pci_bus, slot: pci_slot) if pci_bus and pci_slot
            end
          end.to_xml(
            save_with: Nokogiri::XML::Node::SaveOptions::NO_DECLARATION |
                       Nokogiri::XML::Node::SaveOptions::NO_EMPTY_TAGS |
                       Nokogiri::XML::Node::SaveOptions::FORMAT
          )
        end

        def find_empty(array, start = 0, stop = @nic_adapter_count)
          (start..stop).each do |i|
            return i unless array[i]
          end
          nil
        end

        # Return network name according to interface options.
        def interface_network(libvirt_client, options)
          # no need to get interface network for tcp tunnel config
          return 'tunnel_interface' if options.fetch(:tunnel_type, nil)

          if options[:network_name]
            @logger.debug 'Found network by name'
            return options[:network_name]
          end

          # Get list of all (active and inactive) libvirt networks.
          available_networks = libvirt_networks(libvirt_client)

          return 'public' if options[:iface_type] == :public_network

          if options[:ip]
            address = network_address(options[:ip], options[:netmask])
            available_networks.each do |network|
              if address == network[:network_address]
                @logger.debug 'Found network by ip'
                return network[:name]
              end
            end
          end

          raise Errors::NetworkNotAvailableError, network_name: options[:ip]
        end
      end
    end
  end
end
