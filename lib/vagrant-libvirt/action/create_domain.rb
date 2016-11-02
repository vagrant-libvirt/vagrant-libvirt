require 'log4r'

module VagrantPlugins
  module ProviderLibvirt
    module Action
      class CreateDomain
        include VagrantPlugins::ProviderLibvirt::Util::ErbTemplate

        def initialize(app, _env)
          @logger = Log4r::Logger.new('vagrant_libvirt::action::create_domain')
          @app = app
        end

        def _disk_name(name, disk)
          "#{name}-#{disk[:device]}.#{disk[:type]}"  # disk name
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
          @uuid = config.uuid
          @cpus = config.cpus.to_i
          @cpu_features = config.cpu_features
          @cpu_mode = config.cpu_mode
          @cpu_model = config.cpu_model
          @cpu_fallback = config.cpu_fallback
          @numa_nodes = config.numa_nodes
          @loader = config.loader
          @machine_type = config.machine_type
          @machine_arch = config.machine_arch
          @disk_bus = config.disk_bus
          @nested = config.nested
          @memory_size = config.memory.to_i * 1024
          @management_network_mac = config.management_network_mac
          @domain_volume_cache = config.volume_cache
          @kernel = config.kernel
          @cmd_line = config.cmd_line
          @emulator_path = config.emulator_path
          @initrd = config.initrd
          @dtb = config.dtb
          @graphics_type = config.graphics_type
          @graphics_autoport = config.graphics_autoport
          @graphics_port = config.graphics_port
          @graphics_ip = config.graphics_ip
          @graphics_passwd =  if config.graphics_passwd.to_s.empty?
                                ''
                              else
                                "passwd='#{config.graphics_passwd}'"
                              end
          @video_type = config.video_type
          @video_vram = config.video_vram
          @keymap = config.keymap
          @kvm_hidden = config.kvm_hidden

          @tpm_model = config.tpm_model
          @tpm_type = config.tpm_type
          @tpm_path = config.tpm_path

          # Boot order
          @boot_order = config.boot_order

          # Storage
          @storage_pool_name = config.storage_pool_name
          @disks = config.disks
          @cdroms = config.cdroms

          # Input
          @inputs = config.inputs

          # Channels
          @channels = config.channels

          # PCI device passthrough
          @pcis = config.pcis

          # USB device passthrough
          @usbs = config.usbs
        
          # Redirected devices
          @redirdevs = config.redirdevs
          @redirfilters = config.redirfilters

          # RNG device passthrough
          @rng =config.rng

          config = env[:machine].provider_config
          @domain_type = config.driver

          @os_type = 'hvm'

          # Get path to domain image from the storage pool selected if we have a box.
          if env[:machine].config.vm.box
            actual_volumes =
              env[:machine].provider.driver.connection.volumes.all.select do |x|
                x.pool_name == @storage_pool_name
              end
            domain_volume = ProviderLibvirt::Util::Collection.find_matching(
              actual_volumes,"#{@name}.img")
            raise Errors::DomainVolumeExists if domain_volume.nil?
            @domain_volume_path = domain_volume.path
          end

          # If we have a box, take the path from the domain volume and set our storage_prefix.
          # If not, we dump the storage pool xml to get its defined path.
          # the default storage prefix is typically: /var/lib/libvirt/images/
          if env[:machine].config.vm.box
            storage_prefix = File.dirname(@domain_volume_path) + '/'        # steal
          else
            storage_pool = env[:machine].provider.driver.connection.client.lookup_storage_pool_by_name(@storage_pool_name)
            raise Errors::NoStoragePool if storage_pool.nil?
            xml = Nokogiri::XML(storage_pool.xml_desc)
            storage_prefix = xml.xpath("/pool/target/path").inner_text.to_s + '/'
          end

          @disks.each do |disk|
            disk[:path] ||= _disk_name(@name, disk)

            # On volume creation, the <path> element inside <target>
            # is oddly ignored; instead the path is taken from the
            # <name> element:
            # http://www.redhat.com/archives/libvir-list/2008-August/msg00329.html
            disk[:name] = disk[:path]

            disk[:absolute_path] = storage_prefix + disk[:path]

            if env[:machine].provider.driver.connection.volumes.select do |x|
              x.name == disk[:name] && x.pool_name == @storage_pool_name
            end.empty?
              # make the disk. equivalent to:
              # qemu-img create -f qcow2 <path> 5g
              begin
                env[:machine].provider.driver.connection.volumes.create(
                  name: disk[:name],
                  format_type: disk[:type],
                  path: disk[:absolute_path],
                  capacity: disk[:size],
                  #:allocation => ?,
                  pool_name: @storage_pool_name)
              rescue Fog::Errors::Error => e
                raise Errors::FogDomainVolumeCreateError,
                    error_message:  e.message
              end
            else
              disk[:preexisting] = true
            end
          end

          # Output the settings we're going to use to the user
          env[:ui].info(I18n.t('vagrant_libvirt.creating_domain'))
          env[:ui].info(" -- Name:              #{@name}")
          if @uuid != ''
            env[:ui].info(" -- Forced UUID:       #{@uuid}")
          end
          env[:ui].info(" -- Domain type:       #{@domain_type}")
          env[:ui].info(" -- Cpus:              #{@cpus}")
          @cpu_features.each do |cpu_feature|
            env[:ui].info(" -- CPU Feature:       name=#{cpu_feature[:name]}, policy=#{cpu_feature[:policy]}")
          end
          env[:ui].info(" -- Memory:            #{@memory_size / 1024}M")
          env[:ui].info(" -- Management MAC:    #{@management_network_mac}")
          env[:ui].info(" -- Loader:            #{@loader}")
          if env[:machine].config.vm.box
            env[:ui].info(" -- Base box:          #{env[:machine].box.name}")
          end
          env[:ui].info(" -- Storage pool:      #{@storage_pool_name}")
          env[:ui].info(" -- Image:             #{@domain_volume_path} (#{env[:box_virtual_size]}G)")
          env[:ui].info(" -- Volume Cache:      #{@domain_volume_cache}")
          env[:ui].info(" -- Kernel:            #{@kernel}")
          env[:ui].info(" -- Initrd:            #{@initrd}")
          env[:ui].info(" -- Graphics Type:     #{@graphics_type}")
          env[:ui].info(" -- Graphics Port:     #{@graphics_port}")
          env[:ui].info(" -- Graphics IP:       #{@graphics_ip}")
          env[:ui].info(" -- Graphics Password: #{@graphics_passwd.empty? ? 'Not defined' : 'Defined'}")
          env[:ui].info(" -- Video Type:        #{@video_type}")
          env[:ui].info(" -- Video VRAM:        #{@video_vram}")
          env[:ui].info(" -- Keymap:            #{@keymap}")
          env[:ui].info(" -- TPM Path:          #{@tpm_path}")

          @boot_order.each do |device|
            env[:ui].info(" -- Boot device:        #{device}")
          end

          if @disks.length > 0
            env[:ui].info(" -- Disks:         #{_disks_print(@disks)}")
          end

          @disks.each do |disk|
            msg = " -- Disk(#{disk[:device]}):     #{disk[:absolute_path]}"
            msg += ' Shared' if disk[:shareable]
            msg += ' (Remove only manually)' if disk[:allow_existing]
            msg += ' Not created - using existed.' if disk[:preexisting]
            env[:ui].info(msg)
          end

          if @cdroms.length > 0
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
            env[:ui].info(" -- PCI passthrough:   #{pci[:bus]}:#{pci[:slot]}.#{pci[:function]}")
          end

          if !@rng[:model].nil?
            env[:ui].info(" -- RNG device model:  #{@rng[:model]}")
          end

          @usbs.each do |usb|
            usb_dev = []
            usb_dev.push("bus=#{usb[:bus]}") if usb[:bus]
            usb_dev.push("device=#{usb[:device]}") if usb[:device]
            usb_dev.push("vendor=#{usb[:vendor]}") if usb[:vendor]
            usb_dev.push("product=#{usb[:product]}") if usb[:product]
            env[:ui].info(" -- USB passthrough:   #{usb_dev.join(', ')}")
          end

          if not @redirdevs.empty?
            env[:ui].info(" -- Redirected Devices: ")
            @redirdevs.each do |redirdev|
              msg = "    -> bus=usb, type=#{redirdev[:type]}"
              env[:ui].info(msg)
            end
          end


          if not @redirfilters.empty?
            env[:ui].info(" -- USB Device filter for Redirected Devices: ")
            @redirfilters.each do |redirfilter|
              msg = "    -> class=#{redirfilter[:class]}, "
              msg += "vendor=#{redirfilter[:vendor]}, "
              msg += "product=#{redirfilter[:product]}, "
              msg += "version=#{redirfilter[:version]}, "
              msg += "allow=#{redirfilter[:allow]}"
              env[:ui].info(msg)
            end
          end


          env[:ui].info(" -- Command line : #{@cmd_line}")

          # Create libvirt domain.
          # Is there a way to tell fog to create new domain with already
          # existing volume? Use domain creation from template..
          begin
            server = env[:machine].provider.driver.connection.servers.create(
              xml: to_xml('domain'))
          rescue Fog::Errors::Error => e
            raise Errors::FogCreateServerError, error_message:  e.message
          end

          # Immediately save the ID since it is created at this point.
          env[:machine].id = server.id

          @app.call(env)
        end
      end
    end
  end
end
