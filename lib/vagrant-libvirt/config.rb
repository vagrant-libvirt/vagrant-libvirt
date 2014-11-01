require 'vagrant'

class Numeric
  Alphabet = ('a'..'z').to_a
  def vdev
    s, q = '', self
    (q, r = (q - 1).divmod(26)) && s.prepend(Alphabet[r]) until q.zero?
    'vd'+s
  end
end

module VagrantPlugins
  module ProviderLibvirt
    class Config < Vagrant.plugin('2', :config)
      # manually specify URI
      # will supercede most other options if provided
      attr_accessor :uri

      # A hypervisor name to access via Libvirt.
      attr_accessor :driver

      # The name of the server, where libvirtd is running.
      attr_accessor :host

      # If use ssh tunnel to connect to Libvirt.
      attr_accessor :connect_via_ssh
      # Path towards the libvirt socket
      attr_accessor :socket

      # The username to access Libvirt.
      attr_accessor :username

      # Password for Libvirt connection.
      attr_accessor :password

      # ID SSH key file
      attr_accessor :id_ssh_key_file

      # Libvirt storage pool name, where box image and instance snapshots will
      # be stored.
      attr_accessor :storage_pool_name

      # Turn on to prevent hostname conflicts
      attr_accessor :random_hostname

      # Libvirt default network
      attr_accessor :management_network_name
      attr_accessor :management_network_address
      attr_accessor :management_network_mode

      # Default host prefix (alternative to use project folder name)
      attr_accessor :default_prefix

      # Domain specific settings used while creating new domain.
      attr_accessor :memory
      attr_accessor :cpus
      attr_accessor :cpu_mode
      attr_accessor :disk_bus
      attr_accessor :nic_model_type
      attr_accessor :nested
      attr_accessor :volume_cache
      attr_accessor :kernel
      attr_accessor :cmd_line
      attr_accessor :initrd
      attr_accessor :graphics_type
      attr_accessor :graphics_autoport
      attr_accessor :graphics_port
      attr_accessor :graphics_passwd
      attr_accessor :graphics_ip
      attr_accessor :video_type
      attr_accessor :video_vram

      # Storage
      attr_accessor :disks

      def initialize
        @uri               = UNSET_VALUE
        @driver            = UNSET_VALUE
        @host              = UNSET_VALUE
        @connect_via_ssh   = UNSET_VALUE
        @username          = UNSET_VALUE
        @password          = UNSET_VALUE
        @id_ssh_key_file   = UNSET_VALUE
        @storage_pool_name = UNSET_VALUE
        @random_hostname   = UNSET_VALUE
        @management_network_name    = UNSET_VALUE
        @management_network_address = UNSET_VALUE
        @management_network_mode = UNSET_VALUE

        # Domain specific settings.
        @memory            = UNSET_VALUE
        @cpus              = UNSET_VALUE
        @cpu_mode          = UNSET_VALUE
        @disk_bus          = UNSET_VALUE
        @nic_model_type    = UNSET_VALUE
        @nested            = UNSET_VALUE
        @volume_cache      = UNSET_VALUE
        @kernel            = UNSET_VALUE
        @initrd            = UNSET_VALUE
        @cmd_line          = UNSET_VALUE
        @graphics_type     = UNSET_VALUE
        @graphics_autoport = UNSET_VALUE
        @graphics_port     = UNSET_VALUE
        @graphics_ip       = UNSET_VALUE
        @graphics_passwd   = UNSET_VALUE
        @video_type        = UNSET_VALUE
        @video_vram        = UNSET_VALUE

        # Storage
        @disks             = UNSET_VALUE
      end

      def _get_device(disks)
        disks = [] if disks == UNSET_VALUE
        # skip existing devices and also the first one (vda)
        exist = disks.collect {|x| x[:device]}+[1.vdev.to_s]
        skip = 1		# we're 1 based, not 0 based...
        while true do
          dev = skip.vdev	# get lettered device
          if !exist.include?(dev)
            return dev
          end
          skip+=1
        end
      end

      # NOTE: this will run twice for each time it's needed- keep it idempotent
      def storage(storage_type, options={})
        options = {
          :device => _get_device(@disks),
          :type => 'qcow2',
          :size => '10G',	# matches the fog default
          :path => nil,
          :bus => 'virtio'
        }.merge(options)

        #puts "storage(#{storage_type} --- #{options.to_s})"
        @disks = [] if @disks == UNSET_VALUE

        disk = {
          :device => options[:device],
          :type => options[:type],
          :size => options[:size],
          :path => options[:path],
          :bus => options[:bus],
          :cache => options[:cache] || 'default',
        }

        if storage_type == :file
          @disks << disk	# append
        end
      end

      # code to generate URI from a config moved out of the connect action
      def _generate_uri
        # builds the libvirt connection URI from the given driver config
        # Setup connection uri.
        uri = @driver.dup
        virt_path = case uri
        when 'qemu', 'openvz', 'uml', 'phyp', 'parallels', 'kvm'
          '/system'
        when '@en', 'esx'
          '/'
        when 'vbox', 'vmwarews', 'hyperv'
          '/session'
        else
          raise "Require specify driver #{uri}"
        end
        if uri == 'kvm'
          uri = 'qemu'	# use qemu uri for kvm domain type
        end

        if @connect_via_ssh
          uri << '+ssh://'
          if @username
            uri << @username + '@'
          end

          if @host
            uri << @host
          else
            uri << 'localhost'
          end
        else
          uri << '://'
          uri << @host if @host
        end

        uri << virt_path
        uri << '?no_verify=1'

        if @id_ssh_key_file
          # set ssh key for access to libvirt host
          home_dir = `echo ${HOME}`.chomp
          uri << "\&keyfile=#{home_dir}/.ssh/"+@id_ssh_key_file
        end
        # set path to libvirt socket
        uri << "\&socket="+@socket if @socket
        return uri
      end

      def finalize!
        @driver = 'kvm' if @driver == UNSET_VALUE
        @host = nil if @host == UNSET_VALUE
        @connect_via_ssh = false if @connect_via_ssh == UNSET_VALUE
        @username = nil if @username == UNSET_VALUE
        @password = nil if @password == UNSET_VALUE
        @id_ssh_key_file = 'id_rsa' if @id_ssh_key_file == UNSET_VALUE
        @storage_pool_name = 'default' if @storage_pool_name == UNSET_VALUE
        @random_hostname = false if @random_hostname == UNSET_VALUE
        @management_network_name = 'vagrant-libvirt' if @management_network_name == UNSET_VALUE
        @management_network_address = '192.168.121.0/24' if @management_network_address == UNSET_VALUE
        @management_network_mode = 'nat' if @management_network_mode == UNSET_VALUE

        # generate a URI if none is supplied
        @uri = _generate_uri() if @uri == UNSET_VALUE

        # Domain specific settings.
        @memory = 512 if @memory == UNSET_VALUE
        @cpus = 1 if @cpus == UNSET_VALUE
        @cpu_mode = 'host-model' if @cpu_mode == UNSET_VALUE
        @disk_bus = 'virtio' if @disk_bus == UNSET_VALUE
        @nic_model_type = 'virtio' if @nic_model_type == UNSET_VALUE
        @nested = false if @nested == UNSET_VALUE
        @volume_cache = 'default' if @volume_cache == UNSET_VALUE
        @kernel = nil if @kernel == UNSET_VALUE
        @cmd_line = '' if @cmd_line == UNSET_VALUE
        @initrd = '' if @initrd == UNSET_VALUE
        @graphics_type = 'vnc' if @graphics_type == UNSET_VALUE
        @graphics_autoport = 'yes' if @graphics_port == UNSET_VALUE
        @graphics_autoport = 'no' if @graphics_port != UNSET_VALUE
        if (@graphics_type != 'vnc' && @graphics_port != 'spice') ||
            @graphics_passwd == UNSET_VALUE
          @graphics_passwd = nil
        end
        @graphics_port = 5900 if @graphics_port == UNSET_VALUE
        @graphics_ip = '127.0.0.1' if @graphics_ip == UNSET_VALUE
        @video_type = 'cirrus' if @video_type == UNSET_VALUE
        @video_vram = 9216 if @video_vram == UNSET_VALUE

        # Storage
        @disks = [] if @disks == UNSET_VALUE
      end

      def validate(machine)
      end
    end
  end
end

