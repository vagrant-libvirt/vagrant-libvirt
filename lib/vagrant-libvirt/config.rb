require 'vagrant'

module VagrantPlugins
  module Libvirt
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

      # Libvirt storage pool name, where box image and instance snapshots will
      # be stored.
      attr_accessor :storage_pool_name

      def initialize
        @driver            = UNSET_VALUE
        @host              = UNSET_VALUE
        @connect_via_ssh   = UNSET_VALUE
        @username          = UNSET_VALUE
        @password          = UNSET_VALUE
        @storage_pool_name = UNSET_VALUE
      end

      def finalize!
        @driver   = 'qemu' if @driver == UNSET_VALUE
        @host     = nil if @host     == UNSET_VALUE
        @connect_via_ssh = false if @connect_via_ssh == UNSET_VALUE
        @username = nil if @username == UNSET_VALUE
        @password = nil if @password == UNSET_VALUE
        @storage_pool_name = 'default' if @storage_pool_name == UNSET_VALUE
      end

      def validate(machine)
      end
    end
  end
end

