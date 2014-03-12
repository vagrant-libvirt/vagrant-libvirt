require 'vagrant'

module VagrantPlugins
  module ProviderLibvirt
    class Config < Vagrant.plugin('2', :config)
      # A hypervisor name to access via Libvirt.
      attr_accessor :driver

      # The name of the server, where libvirtd is running.
      attr_accessor :host

      # If use ssh tunnel to connect to Libvirt.
      attr_accessor :connect_via_ssh

      # The username to access Libvirt.
      attr_accessor :username

      # Password for Libvirt connection.
      attr_accessor :password

      # ID SSH key file
      attr_accessor :id_ssh_key_file

      # Libvirt storage pool name, where box image and instance snapshots will
      # be stored.
      attr_accessor :storage_pool_name

      # Libvirt default network
      attr_accessor :management_network_name
      attr_accessor :management_network_address

      # Libvirt default network
      attr_accessor :management_address

      # NFS mount address
      attr_accessor :nfs_address

      # Default host prefix (alternative to use project folder name)
      attr_accessor :default_prefix

      # Domain specific settings used while creating new domain.
      attr_accessor :memory
      attr_accessor :cpus
      attr_accessor :cpu_mode
      attr_accessor :disk_bus
      attr_accessor :nested
      attr_accessor :volume_cache
      attr_accessor :kernel
      attr_accessor :cmd_line
      attr_accessor :initrd

      def initialize
        @driver            = UNSET_VALUE
        @host              = UNSET_VALUE
        @connect_via_ssh   = UNSET_VALUE
        @username          = UNSET_VALUE
        @password          = UNSET_VALUE
        @id_ssh_key_file   = UNSET_VALUE
        @storage_pool_name = UNSET_VALUE
        @management_network_name    = UNSET_VALUE
        @management_network_address = UNSET_VALUE
        @management_address = UNSET_VALUE
        @nfs_address = UNSET_VALUE

        # Domain specific settings.
        @memory            = UNSET_VALUE
        @cpus              = UNSET_VALUE
        @cpu_mode          = UNSET_VALUE
        @disk_bus          = UNSET_VALUE
        @nested            = UNSET_VALUE
        @volume_cache      = UNSET_VALUE
        @kernel            = UNSET_VALUE
        @initrd            = UNSET_VALUE
        @cmd_line          = UNSET_VALUE
      end

      def finalize!
        @driver = 'qemu' if @driver == UNSET_VALUE
        @host = nil if @host == UNSET_VALUE
        @connect_via_ssh = false if @connect_via_ssh == UNSET_VALUE
        @username = nil if @username == UNSET_VALUE
        @password = nil if @password == UNSET_VALUE
        @id_ssh_key_file = 'id_rsa' if @id_ssh_key_file == UNSET_VALUE
        @storage_pool_name = 'default' if @storage_pool_name == UNSET_VALUE
        @management_network_name = 'vagrant-libvirt' if @management_network_name == UNSET_VALUE
        @management_network_address = '192.168.121.0/24' if @management_network_address == UNSET_VALUE
        @management_address = nil if @management_address == UNSET_VALUE
        @nfs_address = nil if @nfs_address == UNSET_VALUE

        # Domain specific settings.
        @memory = 512 if @memory == UNSET_VALUE
        @cpus = 1 if @cpus == UNSET_VALUE
        @cpu_mode = 'host-model' if @cpu_mode == UNSET_VALUE
        @disk_bus = 'virtio' if @disk_bus == UNSET_VALUE
        @nested = false if @nested == UNSET_VALUE
        @volume_cache = 'default' if @volume_cache == UNSET_VALUE
        @kernel = nil if @kernel == UNSET_VALUE
        @cmd_line = '' if @cmd_line == UNSET_VALUE
        @initrd = '' if @initrd == UNSET_VALUE
      end

      def validate(machine)
      end
    end
  end
end

