# frozen_string_literal: true

require 'cgi'

require 'vagrant'
require 'vagrant/action/builtin/mixin_synced_folders'

require 'vagrant-libvirt/errors'
require 'vagrant-libvirt/util/resolvers'
require 'vagrant-libvirt/util/network_util'

module VagrantPlugins
  module ProviderLibvirt
    class Config < Vagrant.plugin('2', :config)
      include Vagrant::Action::Builtin::MixinSyncedFolders
      include VagrantPlugins::ProviderLibvirt::Util::NetworkUtil

      # manually specify URI
      # will supersede most other options if provided
      attr_accessor :uri

      # A hypervisor name to access via Libvirt.
      attr_accessor :driver

      # The name of the server, where Libvirtd is running.
      attr_accessor :host
      attr_accessor :port

      # If use ssh tunnel to connect to Libvirt.
      attr_accessor :connect_via_ssh
      # Path towards the Libvirt socket
      attr_accessor :socket

      # The username to access Libvirt.
      attr_accessor :username

      # Password for Libvirt connection.
      attr_accessor :password

      # ID SSH key file
      attr_accessor :id_ssh_key_file

      attr_accessor :proxy_command

      # Forward port with id 'ssh'
      attr_accessor :forward_ssh_port

      # Libvirt storage pool name, where box image and instance snapshots will
      # be stored.
      attr_accessor :storage_pool_name
      attr_accessor :storage_pool_path

      # Libvirt storage pool where the base image snapshot shall be stored
      attr_accessor :snapshot_pool_name

      # Turn on to prevent hostname conflicts
      attr_accessor :random_hostname

      # Libvirt default network
      attr_accessor :management_network_device
      attr_accessor :management_network_name
      attr_accessor :management_network_address
      attr_accessor :management_network_mode
      attr_accessor :management_network_mac
      attr_accessor :management_network_guest_ipv6
      attr_accessor :management_network_autostart
      attr_accessor :management_network_pci_bus
      attr_accessor :management_network_pci_slot
      attr_accessor :management_network_domain
      attr_accessor :management_network_mtu
      attr_accessor :management_network_keep
      attr_accessor :management_network_driver_iommu
      attr_accessor :management_network_model_type

      # System connection information
      attr_accessor :system_uri

      # Default host prefix (alternative to use project folder name)
      attr_accessor :default_prefix

      # Domain specific settings used while creating new domain.
      attr_accessor :title
      attr_accessor :description
      attr_accessor :uuid
      attr_accessor :memory
      attr_accessor :nodeset
      attr_accessor :memory_backing
      attr_accessor :memtunes
      attr_accessor :channel
      attr_accessor :cpus
      attr_accessor :cpuset
      attr_accessor :cpu_mode
      attr_accessor :cpu_model
      attr_accessor :cpu_fallback
      attr_accessor :cpu_features
      attr_accessor :cpu_topology
      attr_accessor :cpu_affinity
      attr_accessor :shares
      attr_accessor :features
      attr_accessor :features_hyperv
      attr_accessor :clock_absolute
      attr_accessor :clock_adjustment
      attr_accessor :clock_basis
      attr_accessor :clock_offset
      attr_accessor :clock_timezone
      attr_accessor :clock_timers
      attr_accessor :launchsecurity_data
      attr_accessor :numa_nodes
      attr_accessor :loader
      attr_accessor :nvram
      attr_accessor :boot_order
      attr_accessor :machine_type
      attr_accessor :machine_arch
      attr_accessor :machine_virtual_size
      attr_accessor :disk_bus
      attr_accessor :disk_device
      attr_accessor :disk_address_type
      attr_accessor :disk_controller_model
      attr_accessor :disk_driver_opts
      attr_accessor :nic_model_type
      attr_accessor :nested
      attr_accessor :volume_cache # deprecated, kept for backwards compatibility; use disk_driver
      attr_accessor :kernel
      attr_accessor :cmd_line
      attr_accessor :initrd
      attr_accessor :dtb
      attr_accessor :emulator_path
      attr_accessor :graphics_type
      attr_accessor :graphics_autoport
      attr_accessor :graphics_port
      attr_accessor :graphics_websocket
      attr_accessor :graphics_passwd
      attr_accessor :graphics_ip
      attr_accessor :graphics_gl
      attr_accessor :video_type
      attr_accessor :video_vram
      attr_accessor :video_accel3d
      attr_accessor :keymap
      attr_accessor :kvm_hidden
      attr_accessor :sound_type

      # Sets the information for connecting to a host TPM device
      # Only supports socket-based TPMs
      attr_accessor :tpm_model
      attr_accessor :tpm_type
      attr_accessor :tpm_path
      attr_accessor :tpm_version

      # Configure sysinfo values
      attr_accessor :sysinfo

      # Configure the memballoon
      attr_accessor :memballoon_enabled
      attr_accessor :memballoon_model
      attr_accessor :memballoon_pci_bus
      attr_accessor :memballoon_pci_slot

      # Sets the max number of NICs that can be created
      # Default set to 8. Don't change the default unless you know
      # what are doing
      attr_accessor :nic_adapter_count

      # Storage
      attr_accessor :disks
      attr_accessor :cdroms
      attr_accessor :floppies

      # Inputs
      attr_accessor :inputs

      # Channels
      attr_accessor :channels

      # PCI device passthrough
      attr_accessor :pcis

      # Random number device passthrough
      attr_accessor :rng

      # Watchdog device
      attr_accessor :watchdog_dev

      # USB controller
      attr_accessor :usbctl_dev

      # USB device passthrough
      attr_accessor :usbs

      # Redirected devices
      attr_accessor :redirdevs
      attr_accessor :redirfilters

      # smartcard device
      attr_accessor :smartcard_dev

      # Suspend mode
      attr_accessor :suspend_mode

      # Autostart
      attr_accessor :autostart

      # Attach mgmt network
      attr_accessor :mgmt_attach

      # Additional qemuargs arguments
      attr_accessor :qemu_args

      # Additional qemuenv arguments
      attr_accessor :qemu_env

      # Use QEMU session instead of system
      attr_accessor :qemu_use_session

      # Use QEMU Agent to get ip address
      attr_accessor :qemu_use_agent

      # serial consoles
      attr_accessor :serials

      # internal helper attributes
      attr_accessor :host_device_exclude_prefixes

      # list of architectures that support cpu based on https://github.com/libvirt/libvirt/tree/master/src/cpu
      ARCH_SUPPORT_CPU = [
        'aarch64', 'armv6l', 'armv7b', 'armv7l',
        'i686', 'x86_64',
        'ppc64', 'ppc64le',
        's390', 's390x',
      ]

      def initialize
        @logger = Log4r::Logger.new("vagrant_libvirt::config")

        @uri               = UNSET_VALUE
        @driver            = UNSET_VALUE
        @host              = UNSET_VALUE
        @port              = UNSET_VALUE
        @connect_via_ssh   = UNSET_VALUE
        @username          = UNSET_VALUE
        @password          = UNSET_VALUE
        @id_ssh_key_file   = UNSET_VALUE
        @socket            = UNSET_VALUE
        @proxy_command     = UNSET_VALUE
        @forward_ssh_port  = UNSET_VALUE # forward port with id 'ssh'
        @storage_pool_name = UNSET_VALUE
        @snapshot_pool_name = UNSET_VALUE
        @random_hostname   = UNSET_VALUE
        @management_network_device  = UNSET_VALUE
        @management_network_name    = UNSET_VALUE
        @management_network_address = UNSET_VALUE
        @management_network_mode = UNSET_VALUE
        @management_network_mac  = UNSET_VALUE
        @management_network_guest_ipv6 = UNSET_VALUE
        @management_network_autostart = UNSET_VALUE
        @management_network_pci_slot = UNSET_VALUE
        @management_network_pci_bus = UNSET_VALUE
        @management_network_domain = UNSET_VALUE
        @management_network_mtu = UNSET_VALUE
        @management_network_keep = UNSET_VALUE
        @management_network_driver_iommu = UNSET_VALUE
        @management_network_model_type = UNSET_VALUE

        # System connection information
        @system_uri      = UNSET_VALUE

        # Domain specific settings.
        @title             = UNSET_VALUE
        @description       = UNSET_VALUE
        @uuid              = UNSET_VALUE
        @memory            = UNSET_VALUE
        @nodeset           = UNSET_VALUE
        @memory_backing    = UNSET_VALUE
        @memtunes          = {}
        @cpus              = UNSET_VALUE
        @cpuset            = UNSET_VALUE
        @cpu_mode          = UNSET_VALUE
        @cpu_model         = UNSET_VALUE
        @cpu_fallback      = UNSET_VALUE
        @cpu_features      = UNSET_VALUE
        @cpu_topology      = UNSET_VALUE
        @cpu_affinity      = UNSET_VALUE
        @shares            = UNSET_VALUE
        @features          = UNSET_VALUE
        @features_hyperv   = UNSET_VALUE
        @clock_absolute    = UNSET_VALUE
        @clock_adjustment  = UNSET_VALUE
        @clock_basis       = UNSET_VALUE
        @clock_offset      = UNSET_VALUE
        @clock_timezone    = UNSET_VALUE
        @clock_timers      = []
        @launchsecurity_data = UNSET_VALUE
        @numa_nodes        = UNSET_VALUE
        @loader            = UNSET_VALUE
        @nvram             = UNSET_VALUE
        @machine_type      = UNSET_VALUE
        @machine_arch      = UNSET_VALUE
        @machine_virtual_size = UNSET_VALUE
        @disk_bus          = UNSET_VALUE
        @disk_device       = UNSET_VALUE
        @disk_address_type = UNSET_VALUE
        @disk_controller_model = UNSET_VALUE
        @disk_driver_opts  = {}
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
        @graphics_websocket = UNSET_VALUE
        @graphics_ip       = UNSET_VALUE
        @graphics_passwd   = UNSET_VALUE
        @graphics_gl       = UNSET_VALUE
        @video_type        = UNSET_VALUE
        @video_vram        = UNSET_VALUE
        @video_accel3d     = UNSET_VALUE
        @sound_type        = UNSET_VALUE
        @keymap            = UNSET_VALUE
        @kvm_hidden        = UNSET_VALUE

        @tpm_model         = UNSET_VALUE
        @tpm_type          = UNSET_VALUE
        @tpm_path          = UNSET_VALUE
        @tpm_version       = UNSET_VALUE

        @sysinfo           = UNSET_VALUE

        @memballoon_enabled = UNSET_VALUE
        @memballoon_model   = UNSET_VALUE
        @memballoon_pci_bus = UNSET_VALUE
        @memballoon_pci_slot = UNSET_VALUE

        @nic_adapter_count = UNSET_VALUE

        # Boot order
        @boot_order        = []
        # Storage
        @disks             = []
        @cdroms            = []
        @floppies          = []

        # Inputs
        @inputs            = UNSET_VALUE

        # Channels
        @channels          = UNSET_VALUE

        # PCI device passthrough
        @pcis              = UNSET_VALUE

        # Random number device passthrough
        @rng = UNSET_VALUE

        # Watchdog device
        @watchdog_dev      = UNSET_VALUE

        # USB controller
        @usbctl_dev        = UNSET_VALUE

        # USB device passthrough
        @usbs              = UNSET_VALUE

        # Redirected devices
        @redirdevs         = UNSET_VALUE
        @redirfilters      = UNSET_VALUE

        # smartcard device
        @smartcard_dev     = UNSET_VALUE

        # Suspend mode
        @suspend_mode      = UNSET_VALUE

        # Autostart
        @autostart         = UNSET_VALUE

        # Attach mgmt network
        @mgmt_attach       = UNSET_VALUE

        # Additional QEMU commandline arguments
        @qemu_args         = UNSET_VALUE

        # Additional QEMU commandline environment variables
        @qemu_env          = UNSET_VALUE

        @qemu_use_session  = UNSET_VALUE

        # Use Qemu agent to get ip address
        @qemu_use_agent  = UNSET_VALUE

        @serials           = UNSET_VALUE

        # internal options to help override behaviour
        @host_device_exclude_prefixes = UNSET_VALUE
      end

      def boot(device)
        @boot_order << device # append
      end

      def _get_cdrom_dev(cdroms)
        exist = Hash[cdroms.collect { |x| [x[:dev], true] }]
        # hda - hdc
        curr = 'a'.ord
        while curr <= 'd'.ord
          dev = "hd#{curr.chr}"
          if exist[dev]
            curr += 1
            next
          else
            return dev
          end
        end

        # is it better to raise our own error, or let Libvirt cause the exception?
        raise 'Only four cdroms may be attached at a time'
      end


      def _get_floppy_dev(floppies)
        exist = Hash[floppies.collect { |x| [x[:dev], true] }]
        # fda - fdb
        curr = 'a'.ord
        while curr <= 'b'.ord
          dev = "fd#{curr.chr}"
          if exist[dev]
            curr += 1
            next
          else
            return dev
          end
        end

        # is it better to raise our own error, or let Libvirt cause the exception?
        raise 'Only two floppies may be attached at a time'
      end

      def _generate_numa
        @numa_nodes.collect { |x|
          # Perform some validation of cpu values
          unless x[:cpus] =~ /^\d+-\d+$/
            raise 'numa_nodes[:cpus] must be in format "integer-integer"'
          end

          # Convert to KiB
          x[:memory] = x[:memory].to_i * 1024
        }

        # Grab the value of the last @numa_nodes[:cpus] and verify @cpus matches
        # Note: [:cpus] is zero based and @cpus is not, so we need to +1
        last_cpu = @numa_nodes.last[:cpus]
        last_cpu = last_cpu.scan(/\d+$/)[0]
        last_cpu = last_cpu.to_i + 1

        if @cpus != last_cpu.to_i
          raise 'The total number of numa_nodes[:cpus] must equal config.cpus'
        end

        @numa_nodes
      end

      def cpu_feature(options = {})
        if options[:name].nil? || options[:policy].nil?
          raise 'CPU Feature name AND policy must be specified'
        end

        @cpu_features = [] if @cpu_features == UNSET_VALUE

        @cpu_features.push(name:   options[:name],
                           policy: options[:policy])
      end

      def hyperv_feature(options = {})
        if options[:name].nil? || options[:state].nil?
          raise 'Feature name AND state must be specified'
        end

        if options[:name] == 'spinlocks' && options[:retries].nil?
          raise 'Feature spinlocks requires retries parameter'
        end

        @features_hyperv = []  if @features_hyperv == UNSET_VALUE

        if options[:name] == 'spinlocks'
          @features_hyperv.push(name:   options[:name],
                             state: options[:state],
                             retries: options[:retries])
        else
          @features_hyperv.push(name:   options[:name],
                             state: options[:state])
        end
      end

      def clock_timer(options = {})
        if options[:name].nil?
          raise 'Clock timer name must be specified'
        end

        options.each do |key, value|
          case key
            when :name, :track, :tickpolicy, :frequency, :mode, :present
              if value.nil?
                raise "Value of timer option #{key} is nil"
              end
            else
              raise "Unknown clock timer option: #{key}"
          end
        end

        @clock_timers.push(options.dup)
      end

      def cputopology(options = {})
        if options[:sockets].nil? || options[:cores].nil? || options[:threads].nil?
          raise 'CPU topology must have all of sockets, cores and threads specified'
        end

        if @cpu_topology == UNSET_VALUE
          @cpu_topology = {}
        end

        @cpu_topology[:sockets] = options[:sockets]
        @cpu_topology[:cores] = options[:cores]
        @cpu_topology[:threads] = options[:threads]
      end

      def cpuaffinitiy(affinity = {})
        if @cpu_affinity == UNSET_VALUE
          @cpu_affinity = {}
        end

        affinity.each do |vcpu, cpuset|
          @cpu_affinity[vcpu] = cpuset
        end
      end

      def memorybacking(option, config = {})
        case option
        when :source
          raise 'Source type must be specified' if config[:type].nil?
        when :access
          raise 'Access mode must be specified' if config[:mode].nil?
        when :allocation
          raise 'Allocation mode must be specified' if config[:mode].nil?
        end

        @memory_backing = [] if @memory_backing == UNSET_VALUE
        @memory_backing.push(name: option,
                             config: config)
      end

      def memtune(config={})
        if config[:type].nil?
          raise "Missing memtune type"
        end

        unless ['hard_limit', 'soft_limit', 'swap_hard_limit'].include? config[:type]
          raise "Memtune type '#{config[:type]}' not allowed (hard_limit, soft_limit, swap_hard_limit are allowed)"
        end

        if config[:value].nil?
          raise "Missing memtune value"
        end

        opts = config[:options] || {}
        opts[:unit] = opts[:unit] || "KiB"

        @memtunes[config[:type]] = { value: config[:value], config: opts }
      end

      def launchsecurity(options = {})
        if options.fetch(:type) != 'sev'
          raise "Launch security type only supports SEV. Explicitly set 'sev' as a type"
        end

        @launchsecurity_data = {}
        @launchsecurity_data[:type] = options[:type]
        @launchsecurity_data[:cbitpos] = options[:cbitpos] || 47
        @launchsecurity_data[:reducedPhysBits] = options[:reducedPhysBits] || 1
        @launchsecurity_data[:policy] = options[:policy] || "0x0003"
      end

      def input(options = {})
        if options[:type].nil? || options[:bus].nil?
          raise 'Input type AND bus must be specified'
        end

        @inputs = [] if @inputs == UNSET_VALUE

        @inputs.push(type: options[:type],
                     bus:  options[:bus])
      end

      def channel(options = {})
        if options[:type].nil?
          raise 'Channel type must be specified.'
        elsif options[:type] == 'unix' && options[:target_type] == 'guestfwd'
          # Guest forwarding requires a target (ip address) and a port
          if options[:target_address].nil? || options[:target_port].nil? ||
             options[:source_path].nil?
            raise 'guestfwd requires target_address, target_port and source_path'
          end
        end

        @channels = [] if @channels == UNSET_VALUE

        @channels.push(type: options[:type],
                       source_mode: options[:source_mode],
                       source_path: options[:source_path],
                       target_address: options[:target_address],
                       target_name: options[:target_name],
                       target_port: options[:target_port],
                       target_type: options[:target_type],
                       disabled: options[:disabled],
                      )
      end

      def random(options = {})
        if !options[:model].nil? && options[:model] != 'random'
          raise 'The only supported rng backend is "random".'
        end

        @rng = {} if @rng == UNSET_VALUE

        @rng[:model] = options[:model]
      end

      def pci(options = {})
        if options[:bus].nil? || options[:slot].nil? || options[:function].nil?
          raise 'Bus AND slot AND function must be specified. Check `lspci` for that numbers.'
        end

        @pcis = [] if @pcis == UNSET_VALUE

        if options[:domain].nil?
          pci_domain = '0x0000'
        else
          pci_domain = options[:domain]
        end

        @pcis.push(domain:          pci_domain,
                   bus:             options[:bus],
                   slot:            options[:slot],
                   function:        options[:function],
                   guest_domain:    options[:guest_domain],
                   guest_bus:       options[:guest_bus],
                   guest_slot:      options[:guest_slot],
                   guest_function:  options[:guest_function])
      end

      def watchdog(options = {})
        if options[:model].nil?
          raise 'Model must be specified.'
        end

        if @watchdog_dev == UNSET_VALUE
            @watchdog_dev = {}
        end

        @watchdog_dev[:model] = options[:model]
        @watchdog_dev[:action] = options[:action] || 'reset'
      end


      def usb_controller(options = {})
        if options[:model].nil?
          raise 'USB controller model must be specified.'
        end

        if @usbctl_dev == UNSET_VALUE
            @usbctl_dev = {}
        end

        @usbctl_dev[:model] = options[:model]
        @usbctl_dev[:ports] = options[:ports] if options[:ports]
      end

      def usb(options = {})
        if (options[:bus].nil? || options[:device].nil?) && options[:vendor].nil? && options[:product].nil?
          raise 'Bus and device and/or vendor and/or product must be specified. Check `lsusb` for these.'
        end

        @usbs = [] if @usbs == UNSET_VALUE

        @usbs.push(bus:           options[:bus],
                   device:        options[:device],
                   vendor:        options[:vendor],
                   product:       options[:product],
                   startupPolicy: options[:startupPolicy])
      end

      def redirdev(options = {})
        raise 'Type must be specified.' if options[:type].nil?

        @redirdevs = [] if @redirdevs == UNSET_VALUE

        @redirdevs.push(type: options[:type])
      end

      def redirfilter(options = {})
        raise 'Option allow must be specified.' if options[:allow].nil?

        @redirfilters = [] if @redirfilters == UNSET_VALUE

        @redirfilters.push(class: options[:class] || -1,
                           vendor: options[:vendor] || -1,
                           product: options[:product] || -1,
                           version: options[:version] || -1,
                           allow: options[:allow])
      end

      def smartcard(options = {})
        if options[:mode].nil?
          raise 'Option mode must be specified.'
        elsif options[:mode] != 'passthrough'
          raise 'Currently only passthrough mode is supported!'
        elsif options[:type] == 'tcp' && (options[:source_mode].nil? || options[:source_host].nil? || options[:source_service].nil?)
          raise 'If using type "tcp", option "source_mode", "source_host" and "source_service" must be specified.'
        end

        if @smartcard_dev == UNSET_VALUE
          @smartcard_dev = {}
        end

        @smartcard_dev[:mode] = options[:mode]
        @smartcard_dev[:type] = options[:type] || 'spicevmc'
        @smartcard_dev[:source_mode] = options[:source_mode] if @smartcard_dev[:type] == 'tcp'
        @smartcard_dev[:source_host] = options[:source_host] if @smartcard_dev[:type] == 'tcp'
        @smartcard_dev[:source_service] = options[:source_service] if @smartcard_dev[:type] == 'tcp'
      end

      # Disk driver options for primary disk
      def disk_driver(options = {})
        supported_opts = [:cache, :io, :copy_on_read, :discard, :detect_zeroes]
        @disk_driver_opts = options.select { |k,_| supported_opts.include? k }
      end

      # NOTE: this will run twice for each time it's needed- keep it idempotent
      def storage(storage_type, options = {})
        if storage_type == :file
          case options[:device]
          when :cdrom
            _handle_cdrom_storage(options)
          when :floppy
            _handle_floppy_storage(options)
          else
            _handle_disk_storage(options)
          end
        end
      end

      def _handle_cdrom_storage(options = {})
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
          type: 'raw',
          bus: 'ide',
          path: nil
        }.merge(options)

        cdrom = {
          type: options[:type],
          dev: options[:dev],
          bus: options[:bus],
          path: options[:path]
        }

        @cdroms << cdrom
      end

      def _handle_floppy_storage(options = {})
        # <disk type='file' device='floppy'>
        # <source file='/var/lib/libvirt/images/floppy.vfd'/>
        # <target dev='fda' bus='fdc'/>
        # </disk>
        #
        # note the target dev will need to be changed with each floppy drive (fda or fdb)

        options = {
          bus: 'fdc',
          path: nil
        }.merge(options)

        floppy = {
          dev: options[:dev],
          bus: options[:bus],
          path: options[:path]
        }

        @floppies << floppy
      end

      def _handle_disk_storage(options = {})
        options = {
          type: 'qcow2',
          size: '10G', # matches the fog default
          path: nil,
          bus: 'virtio'
        }.merge(options)

        disk = {
          device: options[:device],
          type: options[:type],
          address_type: options[:address_type],
          size: options[:size],
          path: options[:path],
          bus: options[:bus],
          cache: options[:cache] || 'default',
          allow_existing: options[:allow_existing],
          shareable: options[:shareable],
          serial: options[:serial],
          io: options[:io],
          copy_on_read: options[:copy_on_read],
          discard: options[:discard],
          detect_zeroes: options[:detect_zeroes],
          pool: options[:pool], # overrides storage_pool setting for additional disks
          wwn: options[:wwn],
        }

        @disks << disk # append
      end

      def qemuargs(options = {})
        @qemu_args = [] if @qemu_args == UNSET_VALUE

        @qemu_args << options if options[:value]
      end

      def qemuenv(options = {})
        @qemu_env = {} if @qemu_env == UNSET_VALUE

        @qemu_env.merge!(options)
      end

      def serial(options={})
        @serials = [] if @serials == UNSET_VALUE

        options = {
          :type => "pty",
          :source => nil,
        }.merge(options)

        serial = {
          :type => options[:type],
          :source => options[:source],
        }

        @serials << serial
      end

      def _default_uri
        # Determine if any settings except driver provided explicitly, if not
        # and the LIBVIRT_DEFAULT_URI var is set, use that.
        #
        # Skipping driver because that may be set on individual boxes rather
        # than by the user.
        if [
            @connect_via_ssh, @host, @username, @password,
            @id_ssh_key_file, @qemu_use_session, @socket,
        ].none?{ |v| v != UNSET_VALUE }
          if ENV.fetch('LIBVIRT_DEFAULT_URI', '') != ""
            @uri = ENV['LIBVIRT_DEFAULT_URI']
          end
        end
      end

      # code to generate URI from from either the LIBVIRT_URI environment
      # variable or a config moved out of the connect action
      def _generate_uri(qemu_use_session)
        # builds the Libvirt connection URI from the given driver config
        # Setup connection uri.
        uri = @driver.dup
        virt_path = case uri
                    when 'qemu', 'kvm'
                      qemu_use_session ? '/session' : '/system'
                    when 'openvz', 'uml', 'phyp', 'parallels'
                      '/system'
                    when '@en', 'esx'
                      '/'
                    when 'vbox', 'vmwarews', 'hyperv'
                      '/session'
                    else
                      raise "Require specify driver #{uri}"
        end
        if uri == 'kvm'
          uri = 'qemu' # use QEMU uri for KVM domain type
        end

        # turn on ssh if an ssh key file is explicitly provided
        if @connect_via_ssh == UNSET_VALUE && @id_ssh_key_file && @id_ssh_key_file != UNSET_VALUE
          @connect_via_ssh = true
        end

        params = {}

        if @connect_via_ssh == true
          finalize_id_ssh_key_file

          uri += '+ssh://'
          uri += "#{URI.encode_www_form_component(@username)}@" if @username && @username != UNSET_VALUE

          uri += (@host && @host != UNSET_VALUE ? @host : 'localhost')

          params['no_verify'] = '1'
          params['keyfile'] = @id_ssh_key_file if @id_ssh_key_file
        else
          uri += '://'
          uri += @host if @host && @host != UNSET_VALUE
        end

        uri += virt_path

        # set path to Libvirt socket
        params['socket'] = @socket if @socket

        uri += '?' + params.map { |pair| pair.join('=') }.join('&') unless params.empty?
        uri
      end

      def _parse_uri(uri)
        begin
          URI.parse(uri)
        rescue
          raise "@uri set to invalid uri '#{uri}'"
        end
      end

      def finalize!
        _default_uri if @uri == UNSET_VALUE

        # settings which _generate_uri
        @driver = 'kvm' if @driver == UNSET_VALUE
        @password = nil if @password == UNSET_VALUE
        @socket = nil if @socket == UNSET_VALUE

        # If uri isn't set then let's build one from various sources.
        # Default to passing false for qemu_use_session if it's not set.
        if @uri == UNSET_VALUE
          @uri = _generate_uri(@qemu_use_session == UNSET_VALUE ? false : @qemu_use_session)
        end

        finalize_from_uri
        finalize_proxy_command

        # forward port with id 'ssh'
        @forward_ssh_port = false if @forward_ssh_port == UNSET_VALUE

        @storage_pool_name = 'default' if @storage_pool_name == UNSET_VALUE
        @snapshot_pool_name = @storage_pool_name if @snapshot_pool_name == UNSET_VALUE
        @storage_pool_path = nil if @storage_pool_path == UNSET_VALUE
        @random_hostname = false if @random_hostname == UNSET_VALUE
        @management_network_device = 'virbr0' if @management_network_device == UNSET_VALUE
        @management_network_name = 'vagrant-libvirt' if @management_network_name == UNSET_VALUE
        @management_network_address = '192.168.121.0/24' if @management_network_address == UNSET_VALUE
        @management_network_mode = 'nat' if @management_network_mode == UNSET_VALUE
        @management_network_mac = nil if @management_network_mac == UNSET_VALUE
        @management_network_guest_ipv6 = 'yes' if @management_network_guest_ipv6 == UNSET_VALUE
        @management_network_autostart = false if @management_network_autostart == UNSET_VALUE
        @management_network_pci_bus = nil if @management_network_pci_bus == UNSET_VALUE
        @management_network_pci_slot = nil if @management_network_pci_slot == UNSET_VALUE
        @management_network_domain = nil if @management_network_domain == UNSET_VALUE
        @management_network_mtu = nil if @management_network_mtu == UNSET_VALUE
        @management_network_keep = false if @management_network_keep == UNSET_VALUE
        @management_network_driver_iommu = false if @management_network_driver_iommu == UNSET_VALUE
        @management_network_model_type = 'virtio' if @management_network_model_type == UNSET_VALUE

        # Domain specific settings.
        @title = '' if @title == UNSET_VALUE
        @description = '' if @description == UNSET_VALUE
        @uuid = '' if @uuid == UNSET_VALUE
        @machine_type = nil if @machine_type == UNSET_VALUE
        @machine_arch = nil if @machine_arch == UNSET_VALUE
        @memory = 512 if @memory == UNSET_VALUE
        @nodeset = nil if @nodeset == UNSET_VALUE
        @memory_backing = [] if @memory_backing == UNSET_VALUE
        @cpus = 1 if @cpus == UNSET_VALUE
        @cpuset = nil if @cpuset == UNSET_VALUE
        @cpu_mode = if @cpu_mode == UNSET_VALUE
                      # only some architectures support the cpu element
                      if @machine_arch.nil? || ARCH_SUPPORT_CPU.include?(@machine_arch.downcase)
                        'host-model'
                      else
                        nil
                      end
                    else
                      @cpu_mode
                    end
        @cpu_model = if (@cpu_model == UNSET_VALUE) && (@cpu_mode == 'custom')
                       'qemu64'
                     elsif @cpu_mode != 'custom'
                       ''
                     else
                       @cpu_model
          end
        @cpu_topology = {} if @cpu_topology == UNSET_VALUE
        @cpu_affinity = {} if @cpu_affinity == UNSET_VALUE
        @cpu_fallback = 'allow' if @cpu_fallback == UNSET_VALUE
        @cpu_features = [] if @cpu_features == UNSET_VALUE
        @shares = nil if @shares == UNSET_VALUE
        @features = ['acpi','apic','pae'] if @features == UNSET_VALUE
        @features_hyperv = [] if @features_hyperv == UNSET_VALUE
        @clock_absolute = nil if @clock_absolute == UNSET_VALUE
        @clock_adjustment = nil if @clock_adjustment == UNSET_VALUE
        @clock_basis = 'utc' if @clock_basis == UNSET_VALUE
        @clock_offset = 'utc' if @clock_offset == UNSET_VALUE
        @clock_timezone = nil if @clock_timezone == UNSET_VALUE
        @clock_timers = [] if @clock_timers == UNSET_VALUE
        @launchsecurity_data = nil if @launchsecurity_data == UNSET_VALUE
        @numa_nodes = @numa_nodes == UNSET_VALUE ? nil : _generate_numa
        @loader = nil if @loader == UNSET_VALUE
        @nvram = nil if @nvram == UNSET_VALUE
        @machine_virtual_size = nil if @machine_virtual_size == UNSET_VALUE
        @disk_device = @disk_bus == 'scsi' ? 'sda' : 'vda' if @disk_device == UNSET_VALUE
        @disk_bus = @disk_device.start_with?('sd') ? 'scsi' : 'virtio' if @disk_bus == UNSET_VALUE
        if @disk_controller_model == UNSET_VALUE
          if @disk_bus == 'scsi' or @disk_device.start_with?('sd') == 'sd'
            @disk_controller_model = 'virtio-scsi'
          else
            @disk_controller_model = nil
          end
        end
        @disk_address_type = nil if @disk_address_type == UNSET_VALUE
        @disk_driver_opts = {} if @disk_driver_opts == UNSET_VALUE
        @nic_model_type = nil if @nic_model_type == UNSET_VALUE
        @nested = false if @nested == UNSET_VALUE
        @volume_cache = nil if @volume_cache == UNSET_VALUE
        @kernel = nil if @kernel == UNSET_VALUE
        @cmd_line = '' if @cmd_line == UNSET_VALUE
        @initrd = nil if @initrd == UNSET_VALUE
        @dtb = nil if @dtb == UNSET_VALUE
        @graphics_type = 'vnc' if @graphics_type == UNSET_VALUE
        @graphics_autoport = @graphics_type != 'spice' && @graphics_port == UNSET_VALUE ? 'yes' : nil
        if (@graphics_type != 'vnc' && @graphics_type != 'spice') ||
           @graphics_passwd == UNSET_VALUE
          @graphics_passwd = nil
        end
        @graphics_port = @graphics_type == 'spice' ? nil : -1 if @graphics_port == UNSET_VALUE
        @graphics_websocket = @graphics_type == 'spice' ? nil : -1 if @graphics_websocket == UNSET_VALUE
        @graphics_ip = @graphics_type == 'spice' ? nil : '127.0.0.1' if @graphics_ip == UNSET_VALUE
        @video_accel3d = false if @video_accel3d == UNSET_VALUE
        @graphics_gl = @video_accel3d if @graphics_gl == UNSET_VALUE
        @video_type = @video_accel3d ? 'virtio' : 'cirrus' if @video_type == UNSET_VALUE
        @video_vram = 16384 if @video_vram == UNSET_VALUE
        @sound_type = nil if @sound_type == UNSET_VALUE
        @keymap = 'en-us' if @keymap == UNSET_VALUE
        @kvm_hidden = false if @kvm_hidden == UNSET_VALUE
        @tpm_model = 'tpm-tis' if @tpm_model == UNSET_VALUE
        @tpm_type = 'passthrough' if @tpm_type == UNSET_VALUE
        @tpm_path = nil if @tpm_path == UNSET_VALUE
        @tpm_version = nil if @tpm_version == UNSET_VALUE
        @memballoon_enabled = nil if @memballoon_enabled == UNSET_VALUE
        @memballoon_model = 'virtio' if @memballoon_model == UNSET_VALUE
        @memballoon_pci_bus = '0x00' if @memballoon_pci_bus == UNSET_VALUE
        @memballoon_pci_slot = '0x0f' if @memballoon_pci_slot == UNSET_VALUE
        @nic_adapter_count = 8 if @nic_adapter_count == UNSET_VALUE
        @emulator_path = nil if @emulator_path == UNSET_VALUE

        @sysinfo = {} if @sysinfo == UNSET_VALUE

        # Boot order
        @boot_order = [] if @boot_order == UNSET_VALUE

        # Storage
        @disks = [] if @disks == UNSET_VALUE
        @cdroms = [] if @cdroms == UNSET_VALUE
        @cdroms.map! do |cdrom|
          cdrom[:dev] = _get_cdrom_dev(@cdroms) if cdrom[:dev].nil?
          cdrom
        end
        @floppies = [] if @floppies == UNSET_VALUE
        @floppies.map! do |floppy|
          floppy[:dev] = _get_floppy_dev(@floppies) if floppy[:dev].nil?
          floppy
        end

        # Inputs
        @inputs = [{ type: 'mouse', bus: 'ps2' }] if @inputs == UNSET_VALUE

        # Channels
        @channels = [] if @channels == UNSET_VALUE
        if @qemu_use_agent == true
          if @channels.all? { |channel| !channel.fetch(:target_name, '').start_with?('org.qemu.guest_agent.') }
            channel(:type => 'unix', :target_name => 'org.qemu.guest_agent.0', :target_type => 'virtio')
          end
        end
        if @graphics_type == 'spice'
          if @channels.all? { |channel| !channel.fetch(:target_name, '').start_with?('com.redhat.spice.') }
            channel(:type => 'spicevmc', :target_name => 'com.redhat.spice.0', :target_type => 'virtio')
          end
        end

        # filter channels of anything explicitly disabled so it's possible to inject an entry to
        # avoid the automatic addition of the guest_agent above, and disable it from subsequent use.
        @channels = @channels.reject { |channel| channel[:disabled] }.tap {|channel| channel.delete(:disabled) }

        # PCI device passthrough
        @pcis = [] if @pcis == UNSET_VALUE

        # Random number generator passthrough
        @rng = {} if @rng == UNSET_VALUE

        # Watchdog device
        @watchdog_dev = {} if @watchdog_dev == UNSET_VALUE

        # USB device passthrough
        @usbs = [] if @usbs == UNSET_VALUE

        # Redirected devices
        @redirdevs = [] if @redirdevs == UNSET_VALUE
        @redirfilters = [] if @redirfilters == UNSET_VALUE

        # USB controller
        if @usbctl_dev == UNSET_VALUE
          @usbctl_dev = if !@usbs.empty? or !@redirdevs.empty? then {:model => 'qemu-xhci'} else {} end
        end

        # smartcard device
        @smartcard_dev = {} if @smartcard_dev == UNSET_VALUE

        # Suspend mode
        @suspend_mode = 'pause' if @suspend_mode == UNSET_VALUE

        # Autostart
        @autostart = false if @autostart == UNSET_VALUE

        # Attach mgmt network
        @mgmt_attach = true if @mgmt_attach == UNSET_VALUE

        # Additional QEMU commandline arguments
        @qemu_args = [] if @qemu_args == UNSET_VALUE

        # Additional QEMU commandline environment variables
        @qemu_env = {} if @qemu_env == UNSET_VALUE

        @qemu_use_agent = false if @qemu_use_agent == UNSET_VALUE

        @serials = [{:type => 'pty', :source => nil}] if @serials == UNSET_VALUE

        @host_device_exclude_prefixes = ['docker', 'macvtap', 'virbr', 'vnet'] if @host_device_exclude_prefixes == UNSET_VALUE
      end

      def validate(machine)
        errors = _detected_errors

        unless @machine_arch.nil? || ARCH_SUPPORT_CPU.include?(@machine_arch.downcase)
          unsupported = [:cpu_mode, :cpu_model, :nested, :cpu_features, :cpu_topology, :numa_nodes]
          cpu_support_required_by = unsupported.select { |x|
            value = instance_variable_get("@#{x.to_s}")
            next if value.nil?  # not set
            is_bool = !!value == value
            next if is_bool && !value  # boolean and set to false
            next if !is_bool && value.empty?  # not boolean, but empty '', [], {}
            true
          }

          unless cpu_support_required_by.empty?
            errors << "Architecture #{@machine_arch} does not support /domain/cpu XML, which is required when setting the config options #{cpu_support_required_by.join(", ")}"
          end
        end

        # technically this shouldn't occur, but ensure that if somehow it does, it gets rejected.
        if @cpu_mode == 'host-passthrough' && @cpu_model != ''
          errors << "cannot set cpu_model with cpu_mode of 'host-passthrough'. leave model unset or switch mode."
        end

        unless @cpu_model != '' || @cpu_features.empty?
          errors << "cannot set cpu_features with cpu_model unset, please set a model or skip setting features."
        end

        # The @uri and @qemu_use_session should not conflict
        uri = _parse_uri(@uri)
        if (uri.scheme.start_with? "qemu") && (uri.path.include? "session")
          if @qemu_use_session != true
            errors << "the URI and qemu_use_session configuration conflict: uri:'#{@uri}' qemu_use_session:'#{@qemu_use_session}'"
          end
        end

        unless @qemu_use_agent == true || @qemu_use_agent == false
          errors << "libvirt.qemu_use_agent must be a boolean."
        end

        if !@nvram.nil? && @loader.nil?
          errors << "use of 'nvram' requires a 'loader' to be specified, please add one to the configuration"
        end

        if @qemu_use_agent == true
          # if qemu agent is used to obtain domain ip configuration, at least
          # one qemu channel has to be configured. As there are various options,
          # error out and leave configuration to the user
          unless machine.provider_config.channels.any? { |channel| channel[:target_name].start_with?("org.qemu.guest_agent") }
            errors << "qemu agent option enabled, but no qemu agent channel configured: please add at least one qemu agent channel to vagrant config"
          end
        end

        machine.provider_config.disks.each do |disk|
          if disk[:path] && (disk[:path][0] == '/')
            errors << "absolute volume paths like '#{disk[:path]}' not yet supported"
          end
        end

        machine.provider_config.serials.each do |serial|
          if serial[:source] and serial[:source][:path].nil?
            errors << "serial :source requires :path to be defined"
          end
        end

        # this won't be able to fully resolve the disks until the box has
        # been downloaded and any devices that need to be assigned to the
        # disks contained have been allocated
        disk_resolver = ::VagrantPlugins::ProviderLibvirt::Util::DiskDeviceResolver.new
        begin
          disk_resolver.resolve(machine.provider_config.disks)
        rescue Errors::VagrantLibvirtError => e
          errors << "#{e}"
        end

        errors = validate_networks(machine, errors)

        if !machine.provider_config.volume_cache.nil? and machine.provider_config.volume_cache != UNSET_VALUE
          machine.ui.warn("Libvirt Provider: volume_cache is deprecated. Use disk_driver :cache => '#{machine.provider_config.volume_cache}' instead.")

          if !machine.provider_config.disk_driver_opts.empty?
            machine.ui.warn("Libvirt Provider: volume_cache has no effect when disk_driver is defined.")
          end
        end

        # if run via a session, then qemu will be run with user permissions, make sure the user
        # has permissions to access the host paths otherwise there will be an error triggered
        if machine.provider_config.qemu_use_session
          synced_folders(machine).fetch(:"9p", []).each do |_, options|
            unless File.readable?(options[:hostpath])
              errors << "9p synced_folder cannot mount host path #{options[:hostpath]} into guest #{options[:guestpath]} when using qemu session as executing user does not have permissions to read the directory on the user."
            end
          end

          unless synced_folders(machine)[:"virtiofs"].nil?
            machine.ui.warn("Note: qemu session may not support virtiofs for synced_folders, use 9p or enable use of qemu:///system context unless you know what you are doing")
          end
        end

        if [@clock_absolute, @clock_adjustment, @clock_timezone].count {|clock| !clock.nil?} > 1
          errors << "At most, only one of [clock_absolute, clock_adjustment, clock_timezone] may be set."
        end

        errors = validate_sysinfo(machine, errors)

        { 'Libvirt Provider' => errors }
      end

      def merge(other)
        super.tap do |result|
          result.boot_order = other.boot_order != [] ? other.boot_order : boot_order

          c = disks.dup
          c += other.disks
          result.disks = c

          c = cdroms.dup
          c += other.cdroms
          result.cdroms = c

          c = floppies.dup
          c += other.floppies
          result.floppies = c

          result.memtunes = memtunes.merge(other.memtunes)

          result.disk_driver_opts = disk_driver_opts.merge(other.disk_driver_opts)

          result.inputs = inputs != UNSET_VALUE ? inputs.dup + (other.inputs != UNSET_VALUE ? other.inputs : []) : other.inputs

          c = sysinfo == UNSET_VALUE ? {} : sysinfo.dup
          c.merge!(other.sysinfo) { |_k, x, y| x.respond_to?(:each_pair) ? x.merge(y) : x + y } if other.sysinfo != UNSET_VALUE
          result.sysinfo = c

          c = clock_timers.dup
          c += other.clock_timers
          result.clock_timers = c

          c = qemu_env != UNSET_VALUE ? qemu_env.dup : {}
          c.merge!(other.qemu_env) if other.qemu_env != UNSET_VALUE
          result.qemu_env = c

          if serials != UNSET_VALUE
            s = serials.dup
            s += other.serials
            result.serials = s
          end
        end
      end

      private

      def finalize_from_uri
        # Parse uri to extract individual components
        uri = _parse_uri(@uri)

        system_uri = uri.dup
        system_uri.path = '/system'
        @system_uri = system_uri.to_s if @system_uri == UNSET_VALUE

        # only set @connect_via_ssh if not explicitly to avoid overriding
        # and allow an error to occur if the @uri and @connect_via_ssh disagree
        @connect_via_ssh = uri.scheme.include? "ssh" if @connect_via_ssh == UNSET_VALUE

        # Set qemu_use_session based on the URI if it wasn't set by the user
        if @qemu_use_session == UNSET_VALUE
          if (uri.scheme.start_with? "qemu") && (uri.path.include? "session")
            @qemu_use_session = true
          else
            @qemu_use_session = false
          end
        end

        # Extract host values from uri if provided, otherwise set empty string
        @host = uri.host || ""
        @port = uri.port
        # only override username if there is a value provided
        @username = nil if @username == UNSET_VALUE
        @username = uri.user if uri.user
        if uri.query
          params = CGI.parse(uri.query)
          @id_ssh_key_file = params['keyfile'].first if params.has_key?('keyfile')
        end

        finalize_id_ssh_key_file
      end

      def resolve_ssh_key_file(key_file)
        # set ssh key for access to Libvirt host
        # if no slash, prepend $HOME/.ssh/
        key_file = "#{ENV['HOME']}/.ssh/#{key_file}" if key_file && key_file !~ /\A\//

        key_file
      end

      def finalize_id_ssh_key_file
        # resolve based on the following roles
        #  1) if @connect_via_ssh is set to true, and id_ssh_key_file not current set,
        #     set default if the file exists
        #  2) if supplied the key name, attempt to expand based on user home
        #  3) otherwise set to nil

        if @connect_via_ssh == true && @id_ssh_key_file == UNSET_VALUE
          # set default if using ssh while allowing a user using nil to disable this
          id_ssh_key_file = resolve_ssh_key_file('id_rsa')
          id_ssh_key_file = nil if !File.file?(id_ssh_key_file)
        elsif @id_ssh_key_file != UNSET_VALUE
          id_ssh_key_file = resolve_ssh_key_file(@id_ssh_key_file)
        else
          id_ssh_key_file = nil
        end

        @id_ssh_key_file = id_ssh_key_file
      end

      def finalize_proxy_command
        if @connect_via_ssh
          if @proxy_command == UNSET_VALUE
            proxy_command = "ssh '#{@host}' "
            proxy_command += "-p #{@port} " if @port
            proxy_command += "-l '#{@username}' " if @username
            proxy_command += "-i '#{@id_ssh_key_file}' " if @id_ssh_key_file
            proxy_command += '-W %h:%p'
          else
            inputs = { host: @host }
            inputs << { port: @port } if @port
            inputs[:username] = @username if @username
            inputs[:id_ssh_key_file] = @id_ssh_key_file if @id_ssh_key_file

            proxy_command = String.new(@proxy_command)
            # avoid needing to escape '%' symbols
            inputs.each do |key, value|
              proxy_command.gsub!("{#{key}}", value)
            end
          end

          @proxy_command = proxy_command
        else
          @proxy_command = nil
        end
      end

      def validate_networks(machine, errors)
        begin
          networks = configured_networks(machine, @logger)
        rescue Errors::VagrantLibvirtError => e
          errors << "#{e}"

          return
        end

        return if networks.empty?

        networks.each_with_index do |network, index|
          if network[:mac]
            if network[:mac] =~ /\A([0-9a-fA-F]{12})\z/
              network[:mac] = network[:mac].scan(/../).join(':')
            end
            unless network[:mac] =~ /\A([0-9a-fA-F]{2}:){5}([0-9a-fA-F]{2})\z/
              errors << "Configured NIC MAC '#{network[:mac]}' is not in 'xx:xx:xx:xx:xx:xx' or 'xxxxxxxxxxxx' format"
            end
          end

          # only interested in public networks where portgroup is nil, as then source will be a host device
          if network[:iface_type] == :public_network && network[:portgroup] == nil
            exclude_prefixes = @host_device_exclude_prefixes
            # for qemu sessions the management network injected will be a public_network trying to use a libvirt managed device
            if index == 0 and machine.provider_config.mgmt_attach and machine.provider_config.qemu_use_session == true
              exclude_prefixes.delete('virbr')
            end

            devices = machine.provider.driver.host_devices.select do |dev|
              next if dev.empty?
              dev != "lo" && !exclude_prefixes.any? { |exclude| dev.start_with?(exclude) }
            end
            hostdev = network.fetch(:dev, 'eth0')

            if !devices.include?(hostdev)
              errors << "network configuration #{index} for machine #{machine.name} is a public_network referencing host device '#{hostdev}' which does not exist, consider adding ':dev => ....' referencing one of #{devices.join(", ")}"
            end
          end

          unless network[:iface_name].nil?
            restricted_devnames = ['vnet', 'vif', 'macvtap', 'macvlan']
            if restricted_devnames.any? { |restricted| network[:iface_name].start_with?(restricted) }
              errors << "network configuration for machine #{machine.name} with setting :libvirt__iface_name => '#{network[:iface_name]}' starts with a restricted prefix according to libvirt docs https://libvirt.org/formatdomain.html#overriding-the-target-element, please use a device name that does not start with one of #{restricted_devnames.join(", ")}"
            end
          end
        end

        errors
      end

      def validate_sysinfo(machine, errors)
        valid_sysinfo = {
          'bios' => %w[vendor version date release],
          'system' => %w[manufacturer product version serial uuid sku family],
          'base board' => %w[manufacturer product version serial asset location],
          'chassis' => %w[manufacturer version serial asset sku],
          'oem strings' => nil,
        }

        machine.provider_config.sysinfo.each_pair do |block_name, entries|
          block_name = block_name.to_s
          unless valid_sysinfo.key?(block_name)
            errors << "invalid sysinfo element '#{block_name}'; smbios sysinfo elements supported: #{valid_sysinfo.keys.join(', ')}"
            next
          end

          if valid_sysinfo[block_name].nil?
            # assume simple array of text entries
            entries.each do |entry|
              if entry.respond_to?(:to_str)
                if entry.to_s.empty?
                  machine.ui.warn("Libvirt Provider: 'sysinfo.#{block_name}' contains an empty or nil entry and will be discarded")
                end
              else
                errors << "sysinfo.#{block_name} expects entries to be stringy, got #{entry.class} containing '#{entry}'"
              end
            end
          else
            entries.each_pair do |entry_name, entry_text|
              entry_name = entry_name.to_s
              unless valid_sysinfo[block_name].include?(entry_name)
                errors << "'sysinfo.#{block_name}' does not support entry name '#{entry_name}'; entries supported: #{valid_sysinfo[block_name].join(', ')}"
                next
              end

              # this allows removal of entries specified by other Vagrantfile's in the hierarchy
              if entry_text.to_s.empty?
                machine.ui.warn("Libvirt Provider: sysinfo.#{block_name}.#{entry_name} is nil or empty and therefore has no effect.")
              end
            end
          end
        end

        errors
      end
    end
  end
end
