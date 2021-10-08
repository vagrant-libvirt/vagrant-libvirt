# frozen_string_literal: true

require 'log4r'

module VagrantPlugins
  module ProviderLibvirt
    module Action
      class CreateDomain
        include VagrantPlugins::ProviderLibvirt::Util::ErbTemplate
        include VagrantPlugins::ProviderLibvirt::Util::StorageUtil

        def initialize(app, _env)
          @logger = Log4r::Logger.new('vagrant_libvirt::action::create_domain')
          @app = app
        end

        def _disk_name(name, disk)
          "#{name}-#{disk[:device]}.#{disk[:type]}" # disk name
        end

        def _disks_print(disks)
          disks.collect do |x|
            "#{x[:device]}(#{x[:type]},#{x[:size]})"
          end.join(', ')
        end

        def _cdroms_print(cdroms)
          cdroms.collect { |x| x[:dev] }.join(', ')
        end

        def call(env)
          # Get config.
          config = env[:machine].provider_config

          # Gather some info about domain
          @name = env[:domain_name]
          @title = config.title
          vagrantfile = File.join(env[:root_path], (env[:vagrantfile_name] || "Vagrantfile"))
          @description = !config.description.empty? ? config.description : "Source: #{vagrantfile}"
          @uuid = config.uuid
          @cpus = config.cpus.to_i
          @cpuset = config.cpuset
          @cpu_features = config.cpu_features
          @cpu_topology = config.cpu_topology
          @nodeset = config.nodeset
          @features = config.features
          @features_hyperv = config.features_hyperv
          @clock_offset = config.clock_offset
          @clock_timers = config.clock_timers
          @shares = config.shares
          @cpu_mode = config.cpu_mode
          @cpu_model = config.cpu_model
          @cpu_fallback = config.cpu_fallback
          @numa_nodes = config.numa_nodes
          @loader = config.loader
          @nvram = config.nvram
          @machine_type = config.machine_type
          @machine_arch = config.machine_arch
          @disk_bus = config.disk_bus
          @disk_device = config.disk_device
          @disk_driver_opts = config.disk_driver_opts
          @nested = config.nested
          @memory_size = config.memory.to_i * 1024
          @memory_backing = config.memory_backing
          @management_network_mac = config.management_network_mac
          @domain_volume_cache = config.volume_cache || 'default'
          @kernel = config.kernel
          @cmd_line = config.cmd_line
          @emulator_path = config.emulator_path
          @initrd = config.initrd
          @dtb = config.dtb
          @graphics_type = config.graphics_type
          @graphics_autoport = config.graphics_autoport
          @graphics_port = config.graphics_port
          @graphics_ip = config.graphics_ip
          @graphics_passwd = if config.graphics_passwd.to_s.empty?
                               ''
                             else
                               "passwd='#{config.graphics_passwd}'"
                              end
          @video_type = config.video_type
          @sound_type = config.sound_type
          @video_vram = config.video_vram
          @video_accel3d = config.video_accel3d
          @keymap = config.keymap
          @kvm_hidden = config.kvm_hidden

          @tpm_model = config.tpm_model
          @tpm_type = config.tpm_type
          @tpm_path = config.tpm_path
          @tpm_version = config.tpm_version

          # Boot order
          @boot_order = config.boot_order

          # Storage
          @storage_pool_name = config.storage_pool_name
          @snapshot_pool_name = config.snapshot_pool_name
          @domain_volumes = []
          @disks = config.disks
          @cdroms = config.cdroms

          # Input
          @inputs = config.inputs

          # Channels
          @channels = config.channels

          # PCI device passthrough
          @pcis = config.pcis

          # Watchdog device
          @watchdog_dev = config.watchdog_dev

          # USB controller
          @usbctl_dev = config.usbctl_dev

          # USB device passthrough
          @usbs = config.usbs

          # Redirected devices
          @redirdevs = config.redirdevs
          @redirfilters = config.redirfilters

          # Additional QEMU commandline arguments
          @qemu_args = config.qemu_args

          # Additional QEMU commandline environment variables
          @qemu_env = config.qemu_env

          # smartcard device
          @smartcard_dev = config.smartcard_dev

          # RNG device passthrough
          @rng = config.rng

          config = env[:machine].provider_config
          @domain_type = config.driver

          @os_type = 'hvm'

          # Get path to domain image from the storage pool selected if we have a box.
          if env[:machine].config.vm.box
            if @snapshot_pool_name != @storage_pool_name
                pool_name = @snapshot_pool_name
            else
                pool_name = @storage_pool_name
            end
            @logger.debug "Search for volumes in pool: #{pool_name}"
            env[:box_volumes].each_index do |index|
              suffix_index = index > 0 ? "_#{index}" : ''
              domain_volume = env[:machine].provider.driver.connection.volumes.all(
                name: "#{@name}#{suffix_index}.img"
              ).find { |x| x.pool_name == pool_name }
              raise Errors::DomainVolumeExists if domain_volume.nil?
              @domain_volumes.push({
                :dev => (index+1).vdev.to_s,
                :cache => @domain_volume_cache,
                :bus => @disk_bus,
                :path => domain_volume.path,
                :virtual_size => env[:box_volumes][index][:virtual_size]
              })
              end
          end

          # If we have a box, take the path from the domain volume and set our storage_prefix.
          # If not, we dump the storage pool xml to get its defined path.
          # the default storage prefix is typically: /var/lib/libvirt/images/
          if env[:machine].config.vm.box
            storage_prefix = File.dirname(@domain_volumes[0][:path]) + '/' # steal
          else
            storage_prefix = get_disk_storage_prefix(env, @storage_pool_name)
          end

          @serials = config.serials

          @serials.each do |serial|
            next unless serial[:source] && serial[:source][:path]

            dir = File.dirname(serial[:source][:path])
            begin
              FileUtils.mkdir_p(dir)
            rescue ::Errno::EACCES
              raise Errors::SerialCannotCreatePathError,
                    path: dir
            end
          end

          @disks.each do |disk|
            disk[:path] ||= _disk_name(@name, disk)

            # On volume creation, the <path> element inside <target>
            # is oddly ignored; instead the path is taken from the
            # <name> element:
            # http://www.redhat.com/archives/libvir-list/2008-August/msg00329.html
            disk[:name] = disk[:path]

            disk[:absolute_path] = storage_prefix + disk[:path]

            if not disk[:pool].nil?
              disk_pool_name = disk[:pool]
              @logger.debug "Overriding pool name with: #{disk_pool_name}"
              disk_storage_prefix = get_disk_storage_prefix(env, disk_pool_name)
              disk[:absolute_path] = disk_storage_prefix + disk[:path]
              @logger.debug "Overriding disk path with: #{disk[:absolute_path]}"
            else
              disk_pool_name = @storage_pool_name
            end

            # make the disk. equivalent to:
            # qemu-img create -f qcow2 <path> 5g
            begin
              env[:machine].provider.driver.connection.volumes.create(
                name: disk[:name],
                format_type: disk[:type],
                path: disk[:absolute_path],
                capacity: disk[:size],
                owner: storage_uid(env),
                group: storage_gid(env),
                #:allocation => ?,
                pool_name: disk_pool_name
              )
            rescue Libvirt::Error => e
              # It is hard to believe that e contains just a string
              # and no useful error code!
              msg = "Call to virStorageVolCreateXML failed: " +
                    "storage volume '#{disk[:path]}' exists already"
              if e.message == msg and disk[:allow_existing]
                disk[:preexisting] = true
              else
                raise Errors::FogCreateDomainVolumeError,
                      error_message: e.message
              end
            end
          end

          # Output the settings we're going to use to the user
          env[:ui].info(I18n.t('vagrant_libvirt.creating_domain'))
          env[:ui].info(" -- Name:              #{@name}")
          env[:ui].info(" -- Title:             #{@title}") if @title != ''
          env[:ui].info(" -- Description:       #{@description}") if @description != ''
          env[:ui].info(" -- Forced UUID:       #{@uuid}") if @uuid != ''
          env[:ui].info(" -- Domain type:       #{@domain_type}")
          env[:ui].info(" -- Cpus:              #{@cpus}")
          unless @cpuset.nil?
            env[:ui].info(" -- Cpuset:            #{@cpuset}")
          end
          if not @cpu_topology.empty?
            env[:ui].info(" -- CPU topology:   sockets=#{@cpu_topology[:sockets]}, cores=#{@cpu_topology[:cores]}, threads=#{@cpu_topology[:threads]}")
          end
          @cpu_features.each do |cpu_feature|
            env[:ui].info(" -- CPU Feature:       name=#{cpu_feature[:name]}, policy=#{cpu_feature[:policy]}")
          end
          @features.each do |feature|
            env[:ui].info(" -- Feature:           #{feature}")
          end
          @features_hyperv.each do |feature|
            if feature[:name] == 'spinlocks'
              env[:ui].info(" -- Feature (HyperV):  name=#{feature[:name]}, state=#{feature[:state]}, retries=#{feature[:retries]}")
            else
              env[:ui].info(" -- Feature (HyperV):  name=#{feature[:name]}, state=#{feature[:state]}")
            end
          end
          env[:ui].info(" -- Clock offset:      #{@clock_offset}")
          @clock_timers.each do |timer|
            env[:ui].info(" -- Clock timer:       #{timer.map { |k,v| "#{k}=#{v}"}.join(', ')}")
          end
          env[:ui].info(" -- Memory:            #{@memory_size / 1024}M")
          unless @nodeset.nil?
            env[:ui].info(" -- Nodeset:           #{@nodeset}")
          end
          @memory_backing.each do |backing|
            env[:ui].info(" -- Memory Backing:    #{backing[:name]}: #{backing[:config].map { |k,v| "#{k}='#{v}'"}.join(' ')}")
          end
          unless @shares.nil?
            env[:ui].info(" -- Shares:            #{@shares}")
          end
          env[:ui].info(" -- Management MAC:    #{@management_network_mac}")
          env[:ui].info(" -- Loader:            #{@loader}")
          env[:ui].info(" -- Nvram:             #{@nvram}")
          if env[:machine].config.vm.box
            env[:ui].info(" -- Base box:          #{env[:machine].box.name}")
          end
          env[:ui].info(" -- Storage pool:      #{@storage_pool_name}")
          @domain_volumes.each do |volume|
            env[:ui].info(" -- Image(#{volume[:device]}):     #{volume[:path]}, #{volume[:virtual_size].to_GB}G")
          end

          if not @disk_driver_opts.empty?
            env[:ui].info(" -- Disk driver opts:  #{@disk_driver_opts.reject { |k,v| v.nil? }.map { |k,v| "#{k}='#{v}'"}.join(' ')}")
          else
            env[:ui].info(" -- Disk driver opts:  cache='#{@domain_volume_cache}'")
          end

          env[:ui].info(" -- Kernel:            #{@kernel}")
          env[:ui].info(" -- Initrd:            #{@initrd}")
          env[:ui].info(" -- Graphics Type:     #{@graphics_type}")
          env[:ui].info(" -- Graphics Port:     #{@graphics_port}")
          env[:ui].info(" -- Graphics IP:       #{@graphics_ip}")
          env[:ui].info(" -- Graphics Password: #{@graphics_passwd.empty? ? 'Not defined' : 'Defined'}")
          env[:ui].info(" -- Video Type:        #{@video_type}")
          env[:ui].info(" -- Video VRAM:        #{@video_vram}")
          env[:ui].info(" -- Video 3D accel:    #{@video_accel3d}")
          env[:ui].info(" -- Sound Type:	#{@sound_type}")
          env[:ui].info(" -- Keymap:            #{@keymap}")
          env[:ui].info(" -- TPM Backend:       #{@tpm_type}")
          if @tpm_type == 'emulator'
            env[:ui].info(" -- TPM Model:         #{@tpm_model}")
            env[:ui].info(" -- TPM Version:       #{@tpm_version}")
          else
            env[:ui].info(" -- TPM Path:          #{@tpm_path}")
          end

          @boot_order.each do |device|
            env[:ui].info(" -- Boot device:        #{device}")
          end

          unless @disks.empty?
            env[:ui].info(" -- Disks:         #{_disks_print(@disks)}")
          end

          @disks.each do |disk|
            msg = " -- Disk(#{disk[:device]}):     #{disk[:absolute_path]}"
            msg += ' Shared' if disk[:shareable]
            msg += ' (Remove only manually)' if disk[:allow_existing]
            msg += ' Not created - using existed.' if disk[:preexisting]
            env[:ui].info(msg)
          end

          unless @cdroms.empty?
            env[:ui].info(" -- CDROMS:            #{_cdroms_print(@cdroms)}")
          end

          @cdroms.each do |cdrom|
            env[:ui].info(" -- CDROM(#{cdrom[:dev]}):        #{cdrom[:path]}")
          end

          @inputs.each do |input|
            env[:ui].info(" -- INPUT:             type=#{input[:type]}, bus=#{input[:bus]}")
          end

          @channels.each do |channel|
            env[:ui].info(" -- CHANNEL:             type=#{channel[:type]}, mode=#{channel[:source_mode]}")
            env[:ui].info(" -- CHANNEL:             target_type=#{channel[:target_type]}, target_name=#{channel[:target_name]}")
          end

          @pcis.each do |pci|
            env[:ui].info(" -- PCI passthrough:   #{pci[:domain]}:#{pci[:bus]}:#{pci[:slot]}.#{pci[:function]}")
          end

          unless @rng[:model].nil?
            env[:ui].info(" -- RNG device model:  #{@rng[:model]}")
          end

          if not @watchdog_dev.empty?
            env[:ui].info(" -- Watchdog device:   model=#{@watchdog_dev[:model]}, action=#{@watchdog_dev[:action]}")
          end

          if not @usbctl_dev.empty?
            msg = " -- USB controller:    model=#{@usbctl_dev[:model]}"
            msg += ", ports=#{@usbctl_dev[:ports]}" if @usbctl_dev[:ports]
            env[:ui].info(msg)
          end

          @usbs.each do |usb|
            usb_dev = []
            usb_dev.push("bus=#{usb[:bus]}") if usb[:bus]
            usb_dev.push("device=#{usb[:device]}") if usb[:device]
            usb_dev.push("vendor=#{usb[:vendor]}") if usb[:vendor]
            usb_dev.push("product=#{usb[:product]}") if usb[:product]
            env[:ui].info(" -- USB passthrough:   #{usb_dev.join(', ')}")
          end

          unless @redirdevs.empty?
            env[:ui].info(' -- Redirected Devices: ')
            @redirdevs.each do |redirdev|
              msg = "    -> bus=usb, type=#{redirdev[:type]}"
              env[:ui].info(msg)
            end
          end

          unless @redirfilters.empty?
            env[:ui].info(' -- USB Device filter for Redirected Devices: ')
            @redirfilters.each do |redirfilter|
              msg = "    -> class=#{redirfilter[:class]}, "
              msg += "vendor=#{redirfilter[:vendor]}, "
              msg += "product=#{redirfilter[:product]}, "
              msg += "version=#{redirfilter[:version]}, "
              msg += "allow=#{redirfilter[:allow]}"
              env[:ui].info(msg)
            end
          end

          if not @smartcard_dev.empty?
            env[:ui].info(" -- smartcard device:  mode=#{@smartcard_dev[:mode]}, type=#{@smartcard_dev[:type]}")
          end

          @serials.each_with_index do |serial, port|
            if serial[:source]
              env[:ui].info(" -- SERIAL(COM#{port}:       redirect to #{serial[:source][:path]}")
              env[:ui].warn(I18n.t('vagrant_libvirt.warnings.creating_domain_console_access_disabled'))
            end
          end

          unless @qemu_args.empty?
            env[:ui].info(' -- Command line args: ')
            @qemu_args.each do |arg|
              msg = "    -> value=#{arg[:value]}, "
              env[:ui].info(msg)
            end
          end

          unless @qemu_env.empty?
            env[:ui].info(' -- Command line environment variables: ')
            @qemu_env.each do |env_var, env_value|
              msg = "    -> #{env_var}=#{env_value}, "
              env[:ui].info(msg)
            end
          end

          env[:ui].info(" -- Command line : #{@cmd_line}") unless @cmd_line.empty?

          # Create Libvirt domain.
          # Is there a way to tell fog to create new domain with already
          # existing volume? Use domain creation from template..
          xml = to_xml('domain')
          @logger.debug {
            "Creating Domain with XML:\n#{xml}"
          }

          begin
            server = env[:machine].provider.driver.connection.servers.create(
              xml: xml
            )
          rescue Fog::Errors::Error => e
            raise Errors::FogCreateServerError, error_message: e.message
          end

          # Immediately save the ID since it is created at this point.
          env[:machine].id = server.id

          @app.call(env)
        end

        private
        def get_disk_storage_prefix(env, disk_pool_name)
          disk_storage_pool = env[:machine].provider.driver.connection.client.lookup_storage_pool_by_name(disk_pool_name)
          raise Errors::NoStoragePool if disk_storage_pool.nil?
          xml = Nokogiri::XML(disk_storage_pool.xml_desc)
          disk_storage_prefix = xml.xpath('/pool/target/path').inner_text.to_s + '/'
        end
      end
    end
  end
end
