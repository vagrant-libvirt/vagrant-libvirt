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

      def get_domain(machine)
        begin
          domain = connection.servers.get(machine.id)
        rescue Libvirt::RetrieveError => e
          if e.libvirt_code == ProviderLibvirt::Util::ErrorCodes::VIR_ERR_NO_DOMAIN
            @logger.debug("machine #{machine.name} domain not found #{e}.")
            return nil
          else
            raise e
          end
        end

        domain
      end

      def created?(machine)
        domain = get_domain(machine)
        !domain.nil?
      end

      def get_ipaddress(machine)
        # Find the machine
        domain = get_domain(machine)

        if domain.nil?
          # The machine can't be found
          return nil
        end

        get_domain_ipaddress(machine, domain)
      end

      def get_domain_ipaddress(machine, domain)
        if @machine.provider_config.qemu_use_session
          return get_ipaddress_from_system domain.mac
        end

        # Get IP address from dhcp leases table
        begin
          ip_address = get_ipaddress_from_domain(domain)
        rescue Fog::Errors::TimeoutError
          @logger.info('Timeout at waiting for an ip address for machine %s' % machine.name)

          raise
        end

        unless ip_address
          @logger.info('No arp table entry found for machine %s' % machine.name)
          return nil
        end

        ip_address
      end

      def state(machine)
        # may be other error states with initial retreival we can't handle
        begin
          domain = get_domain(machine)
        rescue Libvirt::RetrieveError => e
          @logger.debug("Machine #{machine.id} not found #{e}.")
          return :not_created
        end

        # TODO: terminated no longer appears to be a valid fog state, remove?
        return :not_created if domain.nil? || domain.state.to_sym == :terminated

        domain.state.tr('-', '_').to_sym
      end

      private

      def get_ipaddress_from_system(mac)
        ip_address = nil

        system_connection.list_all_networks.each do |net|
          leases = net.dhcp_leases(mac, 0)
          # Assume the lease expiring last is the current IP address
          ip_address = leases.sort_by { |lse| lse["expirytime"] }.last["ipaddr"] if !leases.empty?
          break if ip_address
        end

        ip_address
      end

      def get_ipaddress_from_domain(domain)
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

    end
  end
end
