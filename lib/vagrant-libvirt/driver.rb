# frozen_string_literal: true

require 'fog/libvirt'
require 'libvirt'
require 'log4r'
require 'json'

module VagrantPlugins
  module ProviderLibvirt
    class Driver
      # store the connection at the instance level as this will be per
      # thread and allows for individual machines to use different
      # connection settings.
      #
      # possibly this should be a connection pool using the connection
      # settings as a key to allow identical connections to be reused
      # across machines.
      @connection = nil
      @system_connection = nil

      def initialize(machine)
        @logger = Log4r::Logger.new('vagrant_libvirt::driver')
        @machine = machine
      end

      def connection
        # If already connected to Libvirt, just use it and don't connect
        # again.
        return @connection if @connection

        # Get config options for Libvirt provider.
        config = @machine.provider_config
        uri = config.uri

        conn_attr = {
          provider: 'libvirt',
          libvirt_uri: uri,
        }
        conn_attr[:libvirt_username] = config.username if config.username
        conn_attr[:libvirt_password] = config.password if config.password

        @logger.info("Connecting to Libvirt (#{uri}) ...")
        begin
          @connection = Fog::Compute.new(conn_attr)
        rescue Fog::Errors::Error => e
          raise Errors::FogLibvirtConnectionError,
                error_message: e.message
        end

        @connection
      end

      def system_connection
        # If already connected to Libvirt, just use it and don't connect
        # again.
        return @system_connection if @system_connection

        config = @machine.provider_config

        @system_connection = Libvirt.open_read_only(config.system_uri)
        @system_connection
      end

      def created?
        domain = get_domain()
        !domain.nil?
      end

      def get_ipaddress(domain=nil)
        # Find the machine
        domain = get_domain() if domain.nil?

        if domain.nil?
          # The machine can't be found
          return nil
        end

        # attempt to get ip address from qemu agent
        if @machine.provider_config.qemu_use_agent == true
          @logger.info('Get IP via qemu agent')
          return get_ipaddress_from_qemu_agent(@machine.config.vm.boot_timeout, domain)
        end

        return get_ipaddress_from_system domain.mac if @machine.provider_config.qemu_use_session

        # Get IP address from dhcp leases table
        begin
          ip_address = get_ipaddress_from_domain(domain)
        rescue Fog::Errors::TimeoutError
          @logger.info("Timeout at waiting for an ip address for machine #{@machine.name}")

          raise
        end

        unless ip_address
          @logger.info("No arp table entry found for machine #{@machine.name}")
          return nil
        end

        ip_address
      end

      def restore_snapshot(snapshot_name)
        domain = get_libvirt_domain()
        snapshot = get_snapshot_if_exists(snapshot_name)
        begin
          # 4 is VIR_DOMAIN_SNAPSHOT_REVERT_FORCE
          # needed due to https://bugzilla.redhat.com/show_bug.cgi?id=1006886
          domain.revert_to_snapshot(snapshot, 4)
        rescue Fog::Errors::Error => e
          raise Errors::SnapshotReversionError, error_message: e.message
        end
      end

      def list_snapshots
        get_libvirt_domain().list_snapshots
      rescue Fog::Errors::Error => e
        raise Errors::SnapshotListError, error_message: e.message
      end

      def delete_snapshot(snapshot_name)
        get_snapshot_if_exists(snapshot_name).delete
      rescue Errors::SnapshotMissing => e
        raise Errors::SnapshotDeletionError, error_message: e.message
      end

      def create_new_snapshot(snapshot_name)
        snapshot_desc = <<-EOF
        <domainsnapshot>
          <name>#{snapshot_name}</name>
          <description>Snapshot for vagrant sandbox</description>
        </domainsnapshot>
        EOF
        get_libvirt_domain().snapshot_create_xml(snapshot_desc)
      rescue Fog::Errors::Error => e
        raise Errors::SnapshotCreationError, error_message: e.message
      end

      def create_snapshot(snapshot_name)
        begin
          delete_snapshot(snapshot_name)
        rescue Errors::SnapshotDeletionError
        end
        create_new_snapshot(snapshot_name)
      end

      # if we can get snapshot description without exception it exists
      def get_snapshot_if_exists(snapshot_name)
        snapshot = get_libvirt_domain().lookup_snapshot_by_name(snapshot_name)
        return snapshot if snapshot.xml_desc
      rescue Libvirt::RetrieveError => e
        raise Errors::SnapshotMissing, error_message: e.message
      end

      def state
        # may be other error states with initial retreival we can't handle
        begin
          domain = get_domain
        rescue Libvirt::RetrieveError => e
          @logger.debug("Machine #{@machine.id} not found #{e}.")
          return :not_created
        end

        # TODO: terminated no longer appears to be a valid fog state, remove?
        return :not_created if domain.nil?
        return :unknown if domain.state.nil?
        return :not_created if domain.state.to_sym == :terminated

        state = domain.state.tr('-', '_').to_sym
        if state == :running
          begin
            get_ipaddress(domain)
          rescue Fog::Errors::TimeoutError => e
            @logger.debug("Machine #{@machine.id} running but no IP address available: #{e}.")
            return :inaccessible
          end
        end

        state
      end

      def get_domain
        begin
          domain = connection.servers.get(@machine.id)
        rescue Libvirt::RetrieveError => e
          raise e unless e.libvirt_code == ProviderLibvirt::Util::ErrorCodes::VIR_ERR_NO_DOMAIN

          @logger.debug("machine #{@machine.name} domain not found #{e}.")
          return nil
        end

        domain
      end

      def list_all_networks
        client = if @machine.provider_config.qemu_use_session
                   system_connection
                else
                  connection.client
                end

        client.list_all_networks.select do |net|
          begin
            net.bridge_name
          rescue Libvirt::Error
            # there does not appear to be a mechanism to determine the type of network, only by
            # querying the attribute and catching the error is it possible to ignore unsupported.
            @logger.debug "Ignoring #{net.name} as it does not support retrieval of bridge_name attribute"
            next
          end
        end
      end

      def host_devices
        @host_devices ||= begin
          cmd = []
          unless @machine.provider_config.proxy_command.nil? || @machine.provider_config.proxy_command.empty?
            cmd = ['ssh', @machine.provider_config.host]
            cmd += ['-p', @machine.provider_config.port.to_s] if @machine.provider_config.port
            cmd += ['-l', @machine.provider_config.username] if @machine.provider_config.username
            cmd += ['-i', @machine.provider_config.id_ssh_key_file] if @machine.provider_config.id_ssh_key_file
          end
          ip_cmd = cmd + %W(ip -j link show)

          result = Vagrant::Util::Subprocess.execute(*ip_cmd)
          raise Errors::FogLibvirtConnectionError unless result.exit_code == 0

          info = JSON.parse(result.stdout)

          (
            info.map { |iface| iface['ifname'] } +
            connection.client.list_all_interfaces.map { |iface| iface.name } +
            list_all_networks.map { |net| net.bridge_name }
          ).uniq.reject(&:empty?)
        end
      end

      def attach_device(xml)
        get_libvirt_domain.attach_device(xml)
      end

      def detach_device(xml)
        get_libvirt_domain.detach_device(xml)
      end

      private

      def get_ipaddress_from_system(mac)
        ip_address = nil

        list_all_networks.each do |net|
          leases = net.dhcp_leases(mac, 0)
          # Assume the lease expiring last is the current IP address
          ip_address = leases.max_by { |lse| lse['expirytime'] }['ipaddr'] unless leases.empty?
          break if ip_address
        end

        ip_address
      end

      def get_ipaddress_from_qemu_agent(timeout, domain=nil)
        ip_address = nil
        addresses = nil
        libvirt_domain = get_libvirt_domain()
        begin
          response = libvirt_domain.qemu_agent_command('{"execute":"guest-network-get-interfaces"}', timeout)
          @logger.debug('Got Response from qemu agent')
          @logger.debug(response)
          addresses = JSON.parse(response)
        rescue StandardError => e
          @logger.debug("Unable to receive IP via qemu agent: [#{e.message}]")
        end

        unless addresses.nil?
          addresses['return'].each do |interface|
            next unless interface.key?('hardware-address')
            next unless domain.mac.downcase == interface['hardware-address'].downcase

            @logger.debug("Found matching interface: [#{interface['name']}]")
            next unless interface.key?('ip-addresses')

            interface['ip-addresses'].each do |ip|
              # returning ipv6 addresses might break windows guests because
              # winrm can't handle connection, winrm fails with "invalid uri"
              next unless ip['ip-address-type'] == 'ipv4'

              ip_address = ip['ip-address']
              @logger.debug("Return IP: [#{ip_address}]")
              break
            end
          end
        end
        ip_address
      end

      def get_ipaddress_from_domain(domain)
        ip_address = nil
        domain.wait_for(2) do
          addresses.each_pair do |_type, ip|
            # Multiple leases are separated with a newline, return only
            # the most recent address
            ip_address = ip[0].split("\n").first unless ip[0].nil?
          end

          !ip_address.nil?
        end

        ip_address
      end

      def get_libvirt_domain
        begin
          libvirt_domain = connection.client.lookup_domain_by_uuid(@machine.id)
        rescue Libvirt::RetrieveError => e
          raise e unless e.libvirt_code == ProviderLibvirt::Util::ErrorCodes::VIR_ERR_NO_DOMAIN

          @logger.debug("machine #{@machine.name} not found #{e}.")
          return nil
        end

        libvirt_domain
      end
    end
  end
end
