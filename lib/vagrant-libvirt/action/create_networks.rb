require 'log4r'
require 'vagrant/util/network_ip'
require 'vagrant/util/scoped_hash_override'
require 'ipaddr'
require 'thread'

module VagrantPlugins
  module ProviderLibvirt
    module Action
      # Prepare all networks needed for domain connections.
      class CreateNetworks
        include Vagrant::Util::NetworkIP
        include Vagrant::Util::ScopedHashOverride
        include VagrantPlugins::ProviderLibvirt::Util::ErbTemplate
        include VagrantPlugins::ProviderLibvirt::Util::NetworkUtil

        @@lock = Mutex.new

        def initialize(app, env)
          mess = 'vagrant_libvirt::action::create_networks'
          @logger = Log4r::Logger.new(mess)
          @app = app

          @available_networks = []
          @options = {}
          @libvirt_client = env[:machine].provider.driver.connection.client
        end

        def call(env)
          # only one vm at a time should try to set up networks
          # otherwise they'll have inconsitent views of current state
          # and conduct redundant operations that cause errors
          @@lock.synchronize do
            # Iterate over networks If some network is not
            # available, create it if possible. Otherwise raise an error.
            configured_networks(env, @logger).each do |options|
              # Only need to create private networks
              next if options[:iface_type] != :private_network ||
                options.fetch(:tunnel_type, nil)
              @logger.debug "Searching for network with options #{options}"

              # should fix other methods so this doesn't have to be instance var
              @options = options

              # Get a list of all (active and inactive) libvirt networks. This
              # list is used throughout this class and should be easier to
              # process than libvirt API calls.
              @available_networks = libvirt_networks(
                                      env[:machine].provider.driver.connection.client)

              # Prepare a hash describing network for this specific interface.
              @interface_network = {
                name:             nil,
                ip_address:       nil,
                netmask:          @options[:netmask],
                network_address:  nil,
                bridge_name:      nil,
                created:          false,
                active:           false,
                autostart:        false,
                guest_ipv6:       @options[:guest_ipv6] || 'yes',
                libvirt_network:  nil
              }

              if @options[:ip]
                handle_ip_option(env)
              elsif @options[:type].to_s == 'dhcp'
                handle_dhcp_private_network(env)
              elsif @options[:network_name]
                handle_network_name_option(env)
              else
                raise Errors::CreateNetworkError, error_message: @options
              end

              autostart_network if @interface_network[:autostart]
              activate_network unless @interface_network[:active]
            end
          end

          @app.call(env)
        end

        private

        def lookup_network_by_ip(ip)
          @logger.debug "looking up network with ip == #{ip}"
          @available_networks.find { |network| network[:network_address] == ip }
        end

        # Return hash of network for specified name, or nil if not found.
        def lookup_network_by_name(network_name)
          @logger.debug "looking up network named #{network_name}"
          @available_networks.find { |network| network[:name] == network_name }
        end

        # Return hash of network for specified bridge, or nil if not found.
        def lookup_bridge_by_name(bridge_name)
          @logger.debug "looking up bridge named #{bridge_name}"
          @available_networks.find { |network| network[:bridge_name] == bridge_name }
        end

        # Throw an error if dhcp setting for an existing network does not
        # match what was configured in the vagrantfile
        # since we always enable dhcp for the management network
        # this ensures we wont start a vm vagrant cant reach
        # Allow the situation where DHCP is not requested (:libvirt__dhcp_enabled == false)
        # but where it is enabled on the virtual network
        def verify_dhcp
          if @interface_network[:dhcp_enabled] == true && @options[:dhcp_enabled] == false
            raise Errors::DHCPMismatch,
                  network_name: @interface_network[:name],
                  requested: @options[:dhcp_enabled] ? 'enabled' : 'disabled'
          end
        end

        # Handle only situations, when ip is specified. Variables @options and
        # @available_networks should be filled before calling this function.
        def handle_ip_option(env)
          return unless @options[:ip]
          net_address = nil
          unless @options[:forward_mode] == 'veryisolated'
            net_address = network_address(@options[:ip], @options[:netmask])

            # Set IP address of network (actually bridge). It will be used as
            # gateway address for machines connected to this network.
            @interface_network[:ip_address] = get_host_ip_addr(net_address)
          end

          @interface_network[:network_address] = net_address

          # if network is veryisolated, search by name
          if @options[:libvirt__forward_mode] == "veryisolated"
            network = lookup_network_by_name(@options[:network_name])
          elsif net_address
            # otherwise, search by ip (if set)
            network = lookup_network_by_ip(net_address)
          else
            # leaving this here to mimic prior behavior. If we get
            # here, something's probably broken.
            network = lookup_network_by_name(@options[:network_name])
          end
          @interface_network = network if network

          if @interface_network[:created]
            verify_dhcp
          end

          if @options[:network_name]
            @logger.debug "Checking that network name does not clash with ip"
            if @interface_network[:created]
              # Just check for mismatch error here - if name and ip from
              # config match together.
              if @options[:network_name] != @interface_network[:name]
                raise Errors::NetworkNameAndAddressMismatch,
                      ip_address:   @options[:ip],
                      network_name: @options[:network_name]
              end
            else
              # Network is not created, but name is set. We need to check,
              # whether network name from config doesn't already exist.
              if lookup_network_by_name @options[:network_name]
                raise Errors::NetworkNameAndAddressMismatch,
                      ip_address:   @options[:ip],
                      network_name: @options[:network_name]
              end

              # Network with 'name' doesn't exist. Set it as name for new
              # network.
              @interface_network[:name] = @options[:network_name]
            end
          end

          # Do we need to create new network?
          unless @interface_network[:created]

            # TODO: stop after some loops. Don't create infinite loops.

            # Is name for new network set? If not, generate a unique one.
            count = 0
            while @interface_network[:name].nil?
              @logger.debug "generating name for network"

              # Generate a network name.
              network_name = env[:root_path].basename.to_s.dup
              network_name << count.to_s
              count += 1

              # Check if network name is unique.
              next if lookup_network_by_name(network_name)

              @interface_network[:name] = network_name
            end

            # Generate a unique name for network bridge.
            @interface_network[:bridge_name] = generate_bridge_name

            # Create a private network.
            create_private_network(env)
          end
        end

        # Handle network_name option, if ip was not specified. Variables
        # @options and @available_networks should be filled before calling this
        # function.
        def handle_network_name_option(env)
          return if @options[:ip] || \
                    !@options[:network_name] || \
                    !@options[:libvirt__forward_mode] == "veryisolated"

          network = lookup_network_by_name(@options[:network_name])
          @interface_network = network if network

          if @options[:libvirt__forward_mode] == "veryisolated"
            # if this interface has a network address, something's wrong.
            if @interface_network[:network_address]
              raise Errors::NetworkNotAvailableError,
                    network_name: @options[:network_name]
            end
          else
            if !@interface_network
              raise Errors::NetworkNotAvailableError,
                    network_name: @options[:network_name]
            else
              verify_dhcp
            end
          end

          # Do we need to create new network?
          unless @interface_network[:created]
            @interface_network[:name] = @options[:network_name]

            # Generate a unique name for network bridge.
            @interface_network[:bridge_name] = generate_bridge_name

            # Create a private network.
            create_private_network(env)
          end
        end

        def handle_dhcp_private_network(env)
          net_address = '172.28.128.0'
          network = lookup_network_by_ip(net_address)
          @interface_network = network if network

          # Do we need to create new network?
          unless @interface_network[:created]
            @interface_network[:name] = 'vagrant-private-dhcp'
            @interface_network[:network_address] = net_address

            # Set IP address of network (actually bridge). It will be used as
            # gateway address for machines connected to this network.
            @interface_network[:ip_address] = get_host_ip_addr(net_address)

            # Generate a unique name for network bridge.
            @interface_network[:bridge_name] = generate_bridge_name

            # Create a private network.
            create_private_network(env)
          end
        end

        # Return provided address or first address of network otherwise
        def get_host_ip_addr(network)
          @options[:host_ip] ? IPAddr.new(@options[:host_ip]) : IPAddr.new(network).succ
        end

        # Return the first available virbr interface name
        def generate_bridge_name
          @logger.debug "generating name for bridge"
          count = 0
          while lookup_bridge_by_name(bridge_name = "virbr#{count}")
            count += 1
          end
          @logger.debug "found available bridge name #{bridge_name}"
          bridge_name
        end

        def create_private_network(env)
          @network_name = @interface_network[:name]
          @network_bridge_name = @interface_network[:bridge_name]
          @network_address = @interface_network[:ip_address]
          @network_netmask = @interface_network[:netmask]
          @guest_ipv6 = @interface_network[:guest_ipv6]

          @network_forward_mode = @options[:forward_mode]
          if @options[:forward_device]
            @network_forward_device = @options[:forward_device]
          end

          if @options[:dhcp_enabled]
            # Find out DHCP addresses pool range.
            network_address = "#{@interface_network[:network_address]}/"
            network_address << "#{@interface_network[:netmask]}"
            net = @interface_network[:network_address] ? IPAddr.new(network_address) : nil

            # First is address of network, second is gateway (by default).
            # So start the range two addresses after network address by default.
            # TODO: Detect if this IP is not set on the interface.
            start_address = @options[:dhcp_start] || net.to_range.begin.succ

            # Default to last possible address. (Stop address must not be broadcast address.)
            stop_address = @options[:dhcp_stop] || (net.to_range.end & IPAddr.new('255.255.255.254'))

            @network_dhcp_enabled = true
            @network_dhcp_bootp_file = @options[:dhcp_bootp_file]
            @network_dhcp_bootp_server = @options[:dhcp_bootp_server]
            @network_range_start = start_address
            @network_range_stop = stop_address
          else
            @network_dhcp_enabled = false
          end

          begin
            @interface_network[:libvirt_network] = \
              @libvirt_client.define_network_xml(to_xml('private_network'))
            @logger.debug "created network"
          rescue => e
            raise Errors::CreateNetworkError, error_message: e.message
          end

          created_networks_file = env[:machine].data_dir + 'created_networks'

          message = 'Saving information about created network '
          message << "#{@interface_network[:name]}, "
          message << "UUID=#{@interface_network[:libvirt_network].uuid} "
          message << "to file #{created_networks_file}."
          @logger.info(message)

          File.open(created_networks_file, 'a') do |file|
            file.puts @interface_network[:libvirt_network].uuid
          end
        end

        def autostart_network
          begin
            @interface_network[:libvirt_network].autostart = true
          rescue => e
            raise Errors::AutostartNetworkError, error_message: e.message
          end
        end

        def activate_network
          begin
            @interface_network[:libvirt_network].create
          rescue => e
            raise Errors::ActivateNetworkError, error_message: e.message
          end
        end

      end
    end
  end
end
