require 'log4r'
require 'vagrant/util/network_ip'
require 'vagrant/util/scoped_hash_override'
require 'ipaddr'

module VagrantPlugins
  module ProviderLibvirt
    module Action
      # Prepare all networks needed for domain connections.
      class CreateNetworks
        include Vagrant::Util::NetworkIP
        include Vagrant::Util::ScopedHashOverride
        include VagrantPlugins::ProviderLibvirt::Util::ErbTemplate
        include VagrantPlugins::ProviderLibvirt::Util::LibvirtUtil

        def initialize(app, env)
          mess = 'vagrant_libvirt::action::create_networks'
          @logger = Log4r::Logger.new(mess)
          @app = app

          @available_networks = []
          @options = {}
          @libvirt_client = env[:libvirt_compute].client
        end

        def call(env)

          # Iterate over networks requested from config. If some network is not
          # available, create it if possible. Otherwise raise an error.
          env[:machine].config.vm.networks.each do |type, options|

            # Get a list of all (active and inactive) libvirt networks. This
            # list is used throughout this class and should be easier to
            # process than libvirt API calls.
            @available_networks = libvirt_networks(env[:libvirt_compute].client)

            # Now, we support private networks only. There are two other types
            # public network and port forwarding, but there are problems with
            # creating them via libvirt API, so this provider doesn't implement
            # them.
            next if type != :private_network

            # Get options for this interface network. Options can be specified
            # in Vagrantfile in short format (:ip => ...), or provider format
            # (:libvirt__network_name => ...).
            @options = scoped_hash_override(options, :libvirt)
            @options = {
              netmask:      '255.255.255.0',
              dhcp_enabled: true,
              forward_mode: 'nat',
            }.merge(@options)

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
              libvirt_network:  nil,
            }

            if @options[:ip]
              handle_ip_option(env)
            elsif @options[:network_name]
              handle_network_name_option
            else
              # TODO: Should be smarter than just using fixed 'default' string.
              @interface_network = lookup_network_by_name('default')
              if !@interface_network
                raise Errors::NetworkNotAvailableError,
                      network_name: 'default'
              end
            end

            autostart_network if !@interface_network[:autostart]
            activate_network if !@interface_network[:active]
          end

          @app.call(env)
        end

        private

        # Return hash of network for specified name, or nil if not found.
        def lookup_network_by_name(network_name)
          @available_networks.each do |network|
            return network if network[:name] == network_name
          end
          nil
        end

        # Return hash of network for specified bridge, or nil if not found.
        def lookup_bridge_by_name(bridge_name)
          @available_networks.each do |network|
            return network if network[:bridge_name] == bridge_name
          end
          nil
        end

        # Handle only situations, when ip is specified. Variables @options and
        # @available_networks should be filled before calling this function.
        def handle_ip_option(env)
          return if !@options[:ip]

          net_address = network_address(@options[:ip], @options[:netmask])
          @interface_network[:network_address] = net_address

          # Set IP address of network (actually bridge). It will be used as
          # gateway address for machines connected to this network.
          net = IPAddr.new(net_address)
          @interface_network[:ip_address] = net.to_range.begin.succ

          # Is there an available network matching to configured ip
          # address?
          @available_networks.each do |available_network|
            if available_network[:network_address] == \
            @interface_network[:network_address]
              @interface_network = available_network
              break
            end
          end

          if @options[:network_name]
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
          if !@interface_network[:created]

            # TODO: stop after some loops. Don't create infinite loops.

            # Is name for new network set? If not, generate a unique one.
            count = 0
            while @interface_network[:name].nil?

              # Generate a network name.
              network_name = env[:root_path].basename.to_s.dup
              network_name << count.to_s
              count += 1

              # Check if network name is unique.
              next if lookup_network_by_name(network_name)

              @interface_network[:name] = network_name
            end

            # Generate a unique name for network bridge.
            count = 0
            while @interface_network[:bridge_name].nil?
              bridge_name = 'virbr'
              bridge_name << count.to_s
              count += 1

              next if lookup_bridge_by_name(bridge_name)

              @interface_network[:bridge_name] = bridge_name
            end

            # Create a private network.
            create_private_network(env)
          end
        end

        # Handle network_name option, if ip was not specified. Variables
        # @options and @available_networks should be filled before calling this
        # function.
        def handle_network_name_option
          return if @options[:ip] || !@options[:network_name]

          @interface_network = lookup_network_by_name(@options[:network_name])
          if !@interface_network
            raise Errors::NetworkNotAvailableError,
                  network_name: @options[:network_name]
          end
        end

        def create_private_network(env)
          @network_name = @interface_network[:name]
          @network_bridge_name = @interface_network[:bridge_name]
          @network_address = @interface_network[:ip_address]
          @network_netmask = @interface_network[:netmask]

          @network_forward_mode = @options[:forward_mode]
          if @options[:forward_device]
            @network_forward_device = @options[:forward_device]
          end

          if @options[:dhcp_enabled]
            # Find out DHCP addresses pool range.
            network_address = "#{@interface_network[:network_address]}/"
            network_address << "#{@interface_network[:netmask]}"
            net = IPAddr.new(network_address)

            # First is address of network, second is gateway.
            # Start the range two
            # addresses after network address.
            # TODO: Detect if this IP is not set on the interface.
            start_address = net.to_range.begin.succ.succ

            # Stop address must not be broadcast.
            stop_address = net.to_range.end & IPAddr.new('255.255.255.254')

            @network_dhcp_enabled = true
            @network_range_start = start_address
            @network_range_stop = stop_address
          else
            @network_dhcp_enabled = false
          end

          begin
            @interface_network[:libvirt_network] = \
              @libvirt_client.define_network_xml(to_xml('private_network'))
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
