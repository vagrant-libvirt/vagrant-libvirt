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
      attr_accessor :management_network_mac
      attr_accessor :management_network_guest_ipv6

      # Default host prefix (alternative to use project folder name)
      attr_accessor :default_prefix

      # Domain specific settings used while creating new domain.
      attr_accessor :uuid
      attr_accessor :memory
      attr_accessor :channel
      attr_accessor :cpus
      attr_accessor :cpu_mode
      attr_accessor :cpu_model
      attr_accessor :cpu_fallback
      attr_accessor :cpu_features
      attr_accessor :numa_nodes
      attr_accessor :loader
      attr_accessor :boot_order
      attr_accessor :machine_type
      attr_accessor :machine_arch
      attr_accessor :machine_virtual_size
      attr_accessor :disk_bus
      attr_accessor :nic_model_type
      attr_accessor :nested
      attr_accessor :volume_cache
      attr_accessor :kernel
      attr_accessor :cmd_line
      attr_accessor :initrd
      attr_accessor :dtb
      attr_accessor :emulator_path
      attr_accessor :graphics_type
      attr_accessor :graphics_autoport
      attr_accessor :graphics_port
      attr_accessor :graphics_passwd
      attr_accessor :graphics_ip
      attr_accessor :video_type
      attr_accessor :video_vram
      attr_accessor :keymap
      attr_accessor :kvm_hidden

      # Sets the information for connecting to a host TPM device
      # Only supports socket-based TPMs
      attr_accessor :tpm_model
      attr_accessor :tpm_type
      attr_accessor :tpm_path

      # Sets the max number of NICs that can be created
      # Default set to 8. Don't change the default unless you know
      # what are doing
      attr_accessor :nic_adapter_count

      # Storage
      attr_accessor :disks
      attr_accessor :cdroms

      # Inputs
      attr_accessor :inputs

      # Channels
      attr_accessor :channels

      # PCI device passthrough
      attr_accessor :pcis

      # Random number device passthrough
      attr_accessor :rng

      # USB device passthrough
      attr_accessor :usbs

      # Redirected devices
      attr_accessor :redirdevs
      attr_accessor :redirfilters

      # Suspend mode
      attr_accessor :suspend_mode

      # Autostart
      attr_accessor :autostart

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
        @management_network_mac  = UNSET_VALUE
        @management_network_guest_ipv6  = UNSET_VALUE

        # Domain specific settings.
        @uuid              = UNSET_VALUE
        @memory            = UNSET_VALUE
        @cpus              = UNSET_VALUE
        @cpu_mode          = UNSET_VALUE
        @cpu_model         = UNSET_VALUE
        @cpu_fallback      = UNSET_VALUE
        @cpu_features      = UNSET_VALUE
        @numa_nodes        = UNSET_VALUE
        @loader            = UNSET_VALUE
        @machine_type      = UNSET_VALUE
        @machine_arch      = UNSET_VALUE
        @machine_virtual_size = UNSET_VALUE
        @disk_bus          = UNSET_VALUE
        @nic_model_type    = UNSET_VALUE
        @nested            = UNSET_VALUE
        @volume_cache      = UNSET_VALUE
        @kernel            = UNSET_VALUE
        @initrd            = UNSET_VALUE
        @dtb               = UNSET_VALUE
        @cmd_line          = UNSET_VALUE
        @emulator_path     = UNSET_VALUE
        @graphics_type     = UNSET_VALUE
        @graphics_autoport = UNSET_VALUE
        @graphics_port     = UNSET_VALUE
        @graphics_ip       = UNSET_VALUE
        @graphics_passwd   = UNSET_VALUE
        @video_type        = UNSET_VALUE
        @video_vram        = UNSET_VALUE
        @keymap            = UNSET_VALUE
        @kvm_hidden        = UNSET_VALUE

        @tpm_model         = UNSET_VALUE
        @tpm_type          = UNSET_VALUE
        @tpm_path          = UNSET_VALUE

        @nic_adapter_count = UNSET_VALUE

        # Boot order
        @boot_order        = []
        # Storage
        @disks             = []
        @cdroms            = []

        # Inputs
        @inputs            = UNSET_VALUE

        # Channels
        @channels          = UNSET_VALUE

        # PCI device passthrough
        @pcis              = UNSET_VALUE

        # Random number device passthrough
        @rng              = UNSET_VALUE

        # USB device passthrough
        @usbs              = UNSET_VALUE
        
        # Redirected devices
        @redirdevs         = UNSET_VALUE
        @redirfilters      = UNSET_VALUE

        # Suspend mode
        @suspend_mode      = UNSET_VALUE

        # Autostart
        @autostart         = UNSET_VALUE
      end

      def boot(device)
        @boot_order << device  # append
      end

      def _get_device(disks)
        # skip existing devices and also the first one (vda)
        exist = disks.collect {|x| x[:device]}+[1.vdev.to_s]
        skip = 1  # we're 1 based, not 0 based...
        while true do
          dev = skip.vdev  # get lettered device
          if !exist.include?(dev)
            return dev
          end
          skip+=1
        end
      end

      def _get_cdrom_dev(cdroms)
        exist = Hash[cdroms.collect{|x| [x[:dev],true]}]
        # hda - hdc
        curr = "a".ord
        while curr <= "d".ord
          dev = "hd" + curr.chr
          if exist[dev]
            curr += 1
            next
          else
            return dev
          end
        end

        # is it better to raise our own error, or let libvirt cause the exception?
        raise 'Only four cdroms may be attached at a time'
      end

      def _generate_numa
        if @cpus % @numa_nodes != 0
          raise 'NUMA nodes must be a factor of CPUs'
        end

        if @memory % @numa_nodes != 0
          raise 'NUMA nodes must be a factor of memory'
        end

        numa = []

        (1..@numa_nodes).each do |node|
          numa_cpu_start = (@cpus / @numa_nodes) * (node - 1)
          numa_cpu_end = (@cpus / @numa_nodes) * node - 1
          numa_cpu = Array(numa_cpu_start..numa_cpu_end).join(',')
          numa_mem = @memory / @numa_nodes

          numa.push({
            id: node,
            cpu: numa_cpu,
            mem: numa_mem
          })
        end

        @numa_nodes = numa
      end

      def cpu_feature(options={})
        if options[:name].nil? || options[:policy].nil?
          raise 'CPU Feature name AND policy must be specified'
        end

        if @cpu_features == UNSET_VALUE
          @cpu_features = []
        end

        @cpu_features.push({
          name:   options[:name],
          policy: options[:policy]
        })
      end

      def input(options={})
        if options[:type].nil? || options[:bus].nil?
          raise 'Input type AND bus must be specified'
        end

        if @inputs == UNSET_VALUE
          @inputs = []
        end

        @inputs.push({
          type: options[:type],
          bus:  options[:bus]
        })
      end

      def channel(options={})
        if options[:type].nil?
            raise "Channel type must be specified."
        elsif options[:type] == 'unix' && options[:target_type] == 'guestfwd'
            # Guest forwarding requires a target (ip address) and a port
            if options[:target_address].nil? || options[:target_port].nil? ||
               options[:source_path].nil?
              raise 'guestfwd requires target_address, target_port and source_path'
            end
        end

        if @channels == UNSET_VALUE
          @channels = []
        end

        @channels.push({
          type: options[:type],
          source_mode: options[:source_mode],
          source_path: options[:source_path],
          target_address: options[:target_address],
          target_name: options[:target_name],
          target_port: options[:target_port],
          target_type: options[:target_type]
        })
      end

      def random(options={})
        if !options[:model].nil? && options[:model] != "random"
          raise 'The only supported rng backend is "random".'
        end

        if @rng == UNSET_VALUE
          @rng = {}
        end

        @rng[:model] = options[:model]
      end

      def pci(options={})
        if options[:bus].nil? || options[:slot].nil? || options[:function].nil?
          raise 'Bus AND slot AND function must be specified. Check `lspci` for that numbers.'
        end

        if @pcis == UNSET_VALUE
          @pcis = []
        end

        @pcis.push({
          bus:       options[:bus],
          slot:      options[:slot],
          function:  options[:function]
        })
      end

      def usb(options={})
        if (options[:bus].nil? || options[:device].nil?) && options[:vendor].nil? && options[:product].nil?
          raise 'Bus and device and/or vendor and/or product must be specified. Check `lsusb` for these.'
        end

        if @usbs == UNSET_VALUE
          @usbs = []
        end

        @usbs.push({
          bus:           options[:bus],
          device:        options[:device],
          vendor:        options[:vendor],
          product:       options[:product],
          startupPolicy: options[:startupPolicy],
        })
      end

      def redirdev(options={})
        if options[:type].nil?
          raise 'Type must be specified.'
        end

        if @redirdevs == UNSET_VALUE
          @redirdevs = []
        end

        @redirdevs.push({
          type: options[:type],
        })
      end

      def redirfilter(options={})
        if options[:allow].nil?
          raise 'Option allow must be specified.'
        end

        if @redirfilters == UNSET_VALUE
          @redirfilters = []
        end

        @redirfilters.push({
          class: options[:class] || -1,
          vendor: options[:class] || -1,
          product: options[:class] || -1,
          version: options[:class] || -1,
          allow: options[:allow],
        })
      end

      # NOTE: this will run twice for each time it's needed- keep it idempotent
      def storage(storage_type, options={})
        if storage_type == :file
          if options[:device] == :cdrom
            _handle_cdrom_storage(options)
          else
            _handle_disk_storage(options)
          end
        end
      end

      def _handle_cdrom_storage(options={})
        # <disk type="file" device="cdrom">
        #   <source file="/home/user/virtio-win-0.1-100.iso"/>
        #   <target dev="hdc"/>
        #   <readonly/>
        #   <address type='drive' controller='0' bus='1' target='0' unit='0'/>
        # </disk>
        #
        # note the target dev will need to be changed with each cdrom drive (hdc, hdd, etc),
        # as will the address unit number (unit=0, unit=1, etc)

        options = {
          :dev => self._get_cdrom_dev(@cdroms),
          :bus => "ide",
          :path => nil,
        }.merge(options)

        cdrom = {
          :dev => options[:dev],
          :bus => options[:bus],
          :path => options[:path]
        }

        @cdroms << cdrom
      end

      def _handle_disk_storage(options={})
        options = {
          :device => _get_device(@disks),
          :type => 'qcow2',
          :size => '10G',  # matches the fog default
          :path => nil,
          :bus => 'virtio'
        }.merge(options)

        disk = {
          :device => options[:device],
          :type => options[:type],
          :size => options[:size],
          :path => options[:path],
          :bus => options[:bus],
          :cache => options[:cache] || 'default',
          :allow_existing => options[:allow_existing],
          :shareable => options[:shareable],
        }

        @disks << disk  # append
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
          uri = 'qemu'  # use qemu uri for kvm domain type
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
          uri << "\&keyfile="
          # if no slash, prepend $HOME/.ssh/
          @id_ssh_key_file.prepend("#{`echo ${HOME}`.chomp}/.ssh/") if @id_ssh_key_file !~ /\A\//
          uri << @id_ssh_key_file
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
        @management_network_mac = nil if @management_network_mac == UNSET_VALUE
        @management_network_guest_ipv6 = 'yes' if @management_network_guest_ipv6 == UNSET_VALUE

        # generate a URI if none is supplied
        @uri = _generate_uri() if @uri == UNSET_VALUE

        # Domain specific settings.
        @uuid = '' if @uuid == UNSET_VALUE
        @memory = 512 if @memory == UNSET_VALUE
        @cpus = 1 if @cpus == UNSET_VALUE
        @cpu_mode = 'host-model' if @cpu_mode == UNSET_VALUE
        @cpu_model = if (@cpu_model == UNSET_VALUE and @cpu_mode == 'custom')
            'qemu64'
          elsif (@cpu_mode != 'custom')
            ''
          end
        @cpu_fallback = 'allow' if @cpu_fallback == UNSET_VALUE
        @cpu_features = [] if @cpu_features == UNSET_VALUE
        @numa_nodes = @numa_nodes == UNSET_VALUE ? nil : _generate_numa()
        @loader = nil if @loader == UNSET_VALUE
        @machine_type = nil if @machine_type == UNSET_VALUE
        @machine_arch = nil if @machine_arch == UNSET_VALUE
        @machine_virtual_size = nil if @machine_virtual_size == UNSET_VALUE
        @disk_bus = 'virtio' if @disk_bus == UNSET_VALUE
        @nic_model_type = 'virtio' if @nic_model_type == UNSET_VALUE
        @nested = false if @nested == UNSET_VALUE
        @volume_cache = 'default' if @volume_cache == UNSET_VALUE
        @kernel = nil if @kernel == UNSET_VALUE
        @cmd_line = '' if @cmd_line == UNSET_VALUE
        @initrd = '' if @initrd == UNSET_VALUE
        @dtb = nil if @dtb == UNSET_VALUE
        @graphics_type = 'vnc' if @graphics_type == UNSET_VALUE
        @graphics_autoport = 'yes' if @graphics_port == UNSET_VALUE
        @graphics_autoport = 'no' if @graphics_port != UNSET_VALUE
        if (@graphics_type != 'vnc' && @graphics_type != 'spice') ||
            @graphics_passwd == UNSET_VALUE
          @graphics_passwd = nil
        end
        @graphics_port = 5900 if @graphics_port == UNSET_VALUE
        @graphics_ip = '127.0.0.1' if @graphics_ip == UNSET_VALUE
        @video_type = 'cirrus' if @video_type == UNSET_VALUE
        @video_vram = 9216 if @video_vram == UNSET_VALUE
        @keymap = 'en-us' if @keymap == UNSET_VALUE
        @kvm_hidden = false if @kvm_hidden == UNSET_VALUE
        @tpm_model = 'tpm-tis' if @tpm_model == UNSET_VALUE
        @tpm_type = 'passthrough' if @tpm_type == UNSET_VALUE
        @tpm_path = nil if @tpm_path == UNSET_VALUE
        @nic_adapter_count = 8 if @nic_adapter_count == UNSET_VALUE
        @emulator_path = nil if @emulator_path == UNSET_VALUE

        # Boot order
        @boot_order = [] if @boot_order == UNSET_VALUE

        # Storage
        @disks = [] if @disks == UNSET_VALUE
        @cdroms = [] if @cdroms == UNSET_VALUE

        # Inputs
        @inputs = [{:type => "mouse", :bus => "ps2"}] if @inputs == UNSET_VALUE

        # Channels
        @channels = [ ] if @channels == UNSET_VALUE

        # PCI device passthrough
        @pcis = [] if @pcis == UNSET_VALUE

        # Random number generator passthrough
        @rng = {} if @rng == UNSET_VALUE

        # USB device passthrough
        @usbs = [] if @usbs == UNSET_VALUE
        
        # Redirected devices
        @redirdevs = [] if @redirdevs == UNSET_VALUE
        @redirfilters = [] if @redirfilters == UNSET_VALUE

        # Suspend mode
        @suspend_mode = "pause" if @suspend_mode == UNSET_VALUE

        # Autostart
        @autostart = false if @autostart == UNSET_VALUE
      end

      def validate(machine)
        errors = _detected_errors

        machine.provider_config.disks.each do |disk|
          if disk[:path] and disk[:path][0] == '/'
            errors << "absolute volume paths like '#{disk[:path]}' not yet supported"
          end
        end

        machine.config.vm.networks.each do |_type, opts|
          if opts[:mac] && opts[:mac].downcase! && !(opts[:mac] =~ /\A([0-9a-f]{2}:){5}([0-9a-f]{2})\z/)
            errors << "Configured NIC MAC '#{opts[:mac]}' is not in 'xx:xx:xx:xx:xx:xx' format"
          end
        end

         { "Libvirt Provider" => errors }
      end

      def merge(other)
        super.tap do |result|
          c = disks.dup
          c += other.disks
          result.disks = c
        end
      end
    end
  end
end
