require 'log4r'

module VagrantPlugins
  module ProviderLibvirt
    module Action

      class CreateDomain
        include VagrantPlugins::ProviderLibvirt::Util::ErbTemplate

        def initialize(app, env)
          @logger = Log4r::Logger.new("vagrant_libvirt::action::create_domain")
          @app = app
        end

        def _disk_name(name, disk)
          return "#{name}-#{disk[:device]}.#{disk[:type]}"	# disk name
        end

        def _disks_print(disks)
          return disks.collect{ |x| x[:device]+'('+x[:type]+','+x[:size]+')' }.join(', ')
        end

        def call(env)
          # Get config.
          config = env[:machine].provider_config

          # Gather some info about domain
          @name = env[:domain_name]
          @cpus = config.cpus
          @cpu_mode = config.cpu_mode
          @disk_bus = config.disk_bus
          @nested = config.nested
          @memory_size = config.memory*1024
          @domain_volume_cache = config.volume_cache
          @kernel = config.kernel
          @cmd_line = config.cmd_line
          @initrd = config.initrd

          # Storage
          @storage_pool_name = config.storage_pool_name
          @disks = config.disks

          config = env[:machine].provider_config
          @domain_type = config.driver

          @os_type = 'hvm'

          # Get path to domain image.
          domain_volume = ProviderLibvirt::Util::Collection.find_matching(
            env[:libvirt_compute].volumes.all, "#{@name}.img")
          raise Errors::DomainVolumeExists if domain_volume == nil
          @domain_volume_path = domain_volume.path

          # the default storage prefix is typically: /var/lib/libvirt/images/
          storage_prefix = File.dirname(@domain_volume_path)+'/'	# steal

          @disks.each do |disk|
            disk[:name] = _disk_name(@name, disk)
            if disk[:path].nil?
              disk[:path] = "#{storage_prefix}#{_disk_name(@name, disk)}"	# automatically chosen!
            end

            # make the disk. equivalent to:
            # qemu-img create -f qcow2 <path> 5g
            begin
              #puts "Making disk: #{d}, #{t}, #{p}"
              domain_volume_disk = env[:libvirt_compute].volumes.create(
                :name => disk[:name],
                :format_type => disk[:type],
                :path => disk[:path],
                :capacity => disk[:size],
                #:allocation => ?,
                :pool_name => @storage_pool_name)
            rescue Fog::Errors::Error => e
              raise Errors::FogDomainVolumeCreateError,
                :error_message => e.message
            end
          end

          # Output the settings we're going to use to the user
          env[:ui].info(I18n.t("vagrant_libvirt.creating_domain"))
          env[:ui].info(" -- Name:          #{@name}")
          env[:ui].info(" -- Domain type:   #{@domain_type}")
          env[:ui].info(" -- Cpus:          #{@cpus}")
          env[:ui].info(" -- Memory:        #{@memory_size/1024}M")
          env[:ui].info(" -- Base box:      #{env[:machine].box.name}")
          env[:ui].info(" -- Storage pool:  #{@storage_pool_name}")
          env[:ui].info(" -- Image:         #{@domain_volume_path}")
          env[:ui].info(" -- Volume Cache:  #{@domain_volume_cache}")
          env[:ui].info(" -- Kernel:        #{@kernel}")
          env[:ui].info(" -- Initrd:        #{@initrd}")
          if @disks.length > 0
            env[:ui].info(" -- Disks:         #{_disks_print(@disks)}")
          end
          @disks.each do |disk|
            env[:ui].info(" -- Disk(#{disk[:device]}):     #{disk[:path]}")
          end
          env[:ui].info(" -- Command line : #{@cmd_line}")

          # Create libvirt domain.
          # Is there a way to tell fog to create new domain with already
          # existing volume? Use domain creation from template..
          begin
            server = env[:libvirt_compute].servers.create(
              :xml => to_xml('domain'))
          rescue Fog::Errors::Error => e
            raise Errors::FogCreateServerError,
              :error_message => e.message
          end

          # Immediately save the ID since it is created at this point.
          env[:machine].id = server.id

          @app.call(env)
        end
      end

    end
  end
end
