require 'log4r'

module VagrantPlugins
  module ProviderLibvirt
    module Action

      # Create a snapshot of base box image. This new snapshot is just new
      # cow image with backing storage pointing to base box image. Use this
      # image as new domain volume.
      class CreateDomainVolume
        include VagrantPlugins::ProviderLibvirt::Util::ErbTemplate

        def initialize(app, env)
          @logger = Log4r::Logger.new("vagrant_libvirt::action::create_domain_volume")
          @app = app
        end

        def call(env)
          env[:ui].info(I18n.t("vagrant_libvirt.creating_domain_volume"))

          # Get config options.
          config = env[:machine].provider_config

          # This is name of newly created image for vm.
          @name = "#{env[:domain_name]}.img"

          # Verify the volume doesn't exist already.
          domain_volume = ProviderLibvirt::Util::Collection.find_matching(
            env[:libvirt_compute].volumes.all, @name)
          raise Errors::DomainVolumeExists if domain_volume

          # Get path to backing image - box volume.
          box_volume = ProviderLibvirt::Util::Collection.find_matching(
            env[:libvirt_compute].volumes.all, env[:box_volume_name])
          @backing_file = box_volume.path

          # Virtual size of image. Take value worked out by HandleBoxImage
          @capacity = env[:box_virtual_size] #G

          # Create new volume from xml template. Fog currently doesn't support
          # volume snapshots directly.
          begin
            domain_volume = env[:libvirt_compute].volumes.create(
              :xml       => to_xml('volume_snapshot'),
              :pool_name => config.storage_pool_name)
          rescue Fog::Errors::Error => e
            raise Errors::FogDomainVolumeCreateError,
              :error_message => e.message
          end

          @app.call(env)
        end
      end

    end
  end
end

