require 'fog/libvirt'
require 'libvirt'
require 'log4r'

module VagrantPlugins
  module ProviderLibvirt
    class Driver
      # store the connection at the process level
      #
      # possibly this should be a connection pool using the connection
      # settings as a key to allow per machine connection attributes
      # to be used.
      @@connection = nil
      @@system_connection = nil

      def initialize(machine)
        @logger = Log4r::Logger.new('vagrant_libvirt::driver')
        @machine = machine
      end

      def connection
        # If already connected to Libvirt, just use it and don't connect
        # again.
        return @@connection if @@connection

        # Get config options for Libvirt provider.
        config = @machine.provider_config
        uri = config.uri

        conn_attr = {}
        conn_attr[:provider] = 'libvirt'
        conn_attr[:libvirt_uri] = uri
        conn_attr[:libvirt_username] = config.username if config.username
        conn_attr[:libvirt_password] = config.password if config.password

        # Setup command for retrieving IP address for newly created machine
        # with some MAC address. Get it from dnsmasq leases table
        ip_command = %q( awk "/$mac/ {print \$1}" /proc/net/arp )
        conn_attr[:libvirt_ip_command] = ip_command

        @logger.info("Connecting to Libvirt (#{uri}) ...")
        begin
          @@connection = Fog::Compute.new(conn_attr)
        rescue Fog::Errors::Error => e
          raise Errors::FogLibvirtConnectionError,
                error_message: e.message
        end

        @@connection
      end

      def system_connection
        # If already connected to Libvirt, just use it and don't connect
        # again.
        return @@system_connection if @@system_connection

        config = @machine.provider_config

        @@system_connection = Libvirt::open_read_only(config.system_uri)
        @@system_connection
      end

      def get_domain(mid)
        begin
          domain = connection.servers.get(mid)
        rescue Libvirt::RetrieveError => e
          if e.libvirt_code == ProviderLibvirt::Util::ErrorCodes::VIR_ERR_NO_DOMAIN
            @logger.debug("machine #{mid} not found #{e}.")
            return nil
          else
            raise e
          end
        end

        domain
      end

      def created?(mid)
        domain = get_domain(mid)
        !domain.nil?
      end

      def get_ipaddress(machine)
        # Find the machine
        domain = get_domain(machine.id)

        if domain.nil?
          # The machine can't be found
          return nil
        end

        if @machine.provider_config.qemu_use_session
          return get_ipaddress_system domain.mac
        end

        # Get IP address from arp table
        begin
          ip_address = get_domain_ipaddress(domain)
        rescue Fog::Errors::TimeoutError
          @logger.info('Timeout at waiting for an ip address for machine %s' % machine.name)
        end

        unless ip_address
          @logger.info('No arp table entry found for machine %s' % machine.name)
          return nil
        end

        ip_address
      end

      def get_ipaddress_system(mac)
        ip_address = nil

        system_connection.list_all_networks.each do |net|
          leases = net.dhcp_leases(mac, 0)
          # Assume the lease expiring last is the current IP address
          ip_address = leases.sort_by { |lse| lse["expirytime"] }.last["ipaddr"] if !leases.empty?
          break if ip_address
        end

        ip_address
      end

      def get_ipaddress_domain(domain)
        ip_address = nil
        domain.wait_for(2) do
          addresses.each_pair do |type, ip|
            # Multiple leases are separated with a newline, return only
            # the most recent address
            ip_address = ip[0].split("\n").first if ip[0] != nil
          end

          ip_address != nil
        end

        ip_address
      end

      def state(machine)
        # may be other error states with initial retreival we can't handle
        begin
          domain = get_domain(machine.id)
        rescue Libvirt::RetrieveError => e
          @logger.debug("Machine #{machine.id} not found #{e}.")
          return :not_created
        end

        # TODO: terminated no longer appears to be a valid fog state, remove?
        return :not_created if domain.nil? || domain.state.to_sym == :terminated

        domain.state.tr('-', '_').to_sym
      end
    end
  end
end
