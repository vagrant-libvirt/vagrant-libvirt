require 'log4r'

module VagrantPlugins
  module ProviderLibvirt
    module Action
      # Create a snapshot of base box image. This new snapshot is just new
      # cow image with backing storage pointing to base box image. Use this
      # image as new domain volume.
      class CreateDomainVolume
        include VagrantPlugins::ProviderLibvirt::Util::ErbTemplate
        include VagrantPlugins::ProviderLibvirt::Util::StorageUtil

        def initialize(app, _env)
          @logger = Log4r::Logger.new('vagrant_libvirt::action::create_domain_volume')
          @app = app
        end

        def call(env)
          env[:ui].info(I18n.t('vagrant_libvirt.creating_domain_volume'))

          # Get config options.
          config = env[:machine].provider_config

          # This is name of newly created image for vm.
          @name = "#{env[:domain_name]}.img"

          # Verify the volume doesn't exist already.
          domain_volume = ProviderLibvirt::Util::Collection.find_matching(
            env[:machine].provider.driver.connection.volumes.all, @name
          )
          raise Errors::DomainVolumeExists if domain_volume

          # Get path to backing image - box volume.
          box_volume = ProviderLibvirt::Util::Collection.find_matching(
            env[:machine].provider.driver.connection.volumes.all, env[:box_volume_name]
          )
          @backing_file = box_volume.path

          # Virtual size of image. Take value worked out by HandleBoxImage
          @capacity = env[:box_virtual_size] # G

          # Create new volume from xml template. Fog currently doesn't support
          # volume snapshots directly.
          begin
            xml = Nokogiri::XML::Builder.new do |xml|
              xml.volume do
                xml.name(@name)
                xml.capacity(@capacity, unit: 'G')
                xml.target do
                  xml.format(type: 'qcow2')
                  xml.permissions do
                    xml.owner storage_uid(env)
                    xml.group storage_gid(env)
                    xml.mode '0600'
                    xml.label 'virt_image_t'
                  end
                end
                xml.backingStore do
                  xml.path(@backing_file)
                  xml.format(type: 'qcow2')
                  xml.permissions do
                    xml.owner storage_uid(env)
                    xml.group storage_gid(env)
                    xml.mode '0600'
                    xml.label 'virt_image_t'
                  end
                end
              end
            end.to_xml(
              save_with: Nokogiri::XML::Node::SaveOptions::NO_DECLARATION |
                         Nokogiri::XML::Node::SaveOptions::NO_EMPTY_TAGS |
                         Nokogiri::XML::Node::SaveOptions::FORMAT
            )
            domain_volume = env[:machine].provider.driver.connection.volumes.create(
              xml: xml,
              pool_name: config.storage_pool_name
            )
          rescue Fog::Errors::Error => e
            raise Errors::FogDomainVolumeCreateError,
                  error_message: e.message
          end

          @app.call(env)
        end
      end
    end
  end
end
