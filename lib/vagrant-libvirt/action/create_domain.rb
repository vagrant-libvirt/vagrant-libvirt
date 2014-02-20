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

          config = env[:machine].provider_config
          @domain_type = config.driver

          @os_type = 'hvm'

          # Get path to domain image.
          domain_volume = ProviderLibvirt::Util::Collection.find_matching(
            env[:libvirt_compute].volumes.all, "#{@name}.img")
          raise Errors::DomainVolumeExists if domain_volume == nil
          @domain_volume_path = domain_volume.path

          # Output the settings we're going to use to the user
          env[:ui].info(I18n.t("vagrant_libvirt.creating_domain"))
          env[:ui].info(" -- Name:          #{@name}")
          env[:ui].info(" -- Domain type:   #{@domain_type}")
          env[:ui].info(" -- Cpus:          #{@cpus}")
          env[:ui].info(" -- Memory:        #{@memory_size/1024}M")
          env[:ui].info(" -- Base box:      #{env[:machine].box.name}")
          env[:ui].info(" -- Storage pool:  #{env[:machine].provider_config.storage_pool_name}")
          env[:ui].info(" -- Image:         #{@domain_volume_path}")
          env[:ui].info(" -- Volume Cache:  #{@domain_volume_cache}")
          env[:ui].info(" -- Kernel:        #{@kernel}")
          env[:ui].info(" -- Initrd:        #{@initrd}")
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
