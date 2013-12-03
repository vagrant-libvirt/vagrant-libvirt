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
      attr_accessor :default_network

      # Domain specific settings used while creating new domain.
      attr_accessor :memory
      attr_accessor :cpus
      attr_accessor :nested
      attr_accessor :volume_cache

      def initialize
        @driver            = UNSET_VALUE
        @host              = UNSET_VALUE
        @connect_via_ssh   = UNSET_VALUE
        @username          = UNSET_VALUE
        @password          = UNSET_VALUE
        @id_ssh_key_file   = UNSET_VALUE
        @storage_pool_name = UNSET_VALUE
        @default_network   = UNSET_VALUE

        # Domain specific settings.
        @memory            = UNSET_VALUE
        @cpus              = UNSET_VALUE
        @nested            = UNSET_VALUE
        @volume_cache      = UNSET_VALUE
      end

      def finalize!
        @driver = 'qemu' if @driver == UNSET_VALUE
        @host = nil if @host == UNSET_VALUE
        @connect_via_ssh = false if @connect_via_ssh == UNSET_VALUE
        @username = nil if @username == UNSET_VALUE
        @password = nil if @password == UNSET_VALUE
        @id_ssh_key_file = nil if @id_ssh_key_file == UNSET_VALUE
        @storage_pool_name = 'default' if @storage_pool_name == UNSET_VALUE
        @default_network = 'default' if @default_network == UNSET_VALUE

        # Domain specific settings.
        @memory = 512 if @memory == UNSET_VALUE
        @cpus = 1 if @cpus == UNSET_VALUE
        @nested = false if @nested == UNSET_VALUE
        @volume_cache = 'default' if @volume_cache == UNSET_VALUE
      end

      def validate(machine)
      end
    end
  end
end

