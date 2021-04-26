require 'log4r'
require 'nokogiri'

module VagrantPlugins
  module ProviderLibvirt
    module Action
      class DestroyDomain
        def initialize(app, _env)
          @logger = Log4r::Logger.new('vagrant_libvirt::action::destroy_domain')
          @app = app
        end

        def call(env)
          # Destroy the server, remove the tracking ID
          env[:ui].info(I18n.t('vagrant_libvirt.destroy_domain'))

          # Must delete any snapshots before domain can be destroyed
          # Fog Libvirt currently doesn't support snapshots. Use
          # ruby-libvirt client directly. Note this is racy, see
          # http://www.libvirt.org/html/libvirt-libvirt.html#virDomainSnapshotListNames
          libvirt_domain = env[:machine].provider.driver.connection.client.lookup_domain_by_uuid(
            env[:machine].id
          )
          begin
            libvirt_domain.list_snapshots.each do |name|
              @logger.info("Deleting snapshot '#{name}'")
              begin
                libvirt_domain.lookup_snapshot_by_name(name).delete
              rescue => e
                raise Errors::DeleteSnapshotError, error_message: e.message
              end
            end
          rescue
            # Some drivers (xen) don't support getting list of snapshots,
            # not much can be done here about it
            @logger.warn("Failed to get list of snapshots")
          end

          # must remove managed saves
          libvirt_domain.managed_save_remove if libvirt_domain.has_managed_save?

          domain = env[:machine].provider.driver.connection.servers.get(env[:machine].id.to_s)

          if env[:machine].provider_config.disks.empty? &&
             env[:machine].provider_config.cdroms.empty?
            # if using default configuration of disks and cdroms
            # cdroms are consider volumes, but cannot be destroyed
            domain.destroy(destroy_volumes: true)
          else
            domain.destroy(destroy_volumes: false)
            
            root_diskname = []
            begin
              box_xml = env[:machine].box.directory.join('box.xml').to_s
              xml = Nokogiri::XML(File.open(box_xml))
              xml.xpath('/domain/devices/disk/source/@file').each_with_index do |volume, index|
                device = (index + 1).vdev.to_s
                root_diskname << "#{libvirt_domain.name}-#{device}.qcow2"
              end
            rescue
              root_diskname << "#{libvirt_domain.name}-vda.qcow2"
            end
            
            # remove root storage
            domain.volumes.select do |root_disk|
              if root_diskname.include? root_disk.name 
                root_disk.destroy
              end
            end

            env[:machine].provider_config.disks.each_with_index do |disk, index|
              # shared disks remove only manually or ???
              next if disk[:allow_existing]
              disk[:device] = (index + 5).vdev.to_s
              diskname = libvirt_domain.name + '-' + disk[:device] + '.' + disk[:type].to_s
              # diskname is unique
              libvirt_disk = domain.volumes.select do |x|
                x.name == diskname
              end.first
              if libvirt_disk
                libvirt_disk.destroy
              elsif disk[:path]
                poolname = env[:machine].provider_config.storage_pool_name
                libvirt_disk = domain.volumes.select do |x|
                  # FIXME: can remove pool/target.img and pool/123/target.img
                  x.path =~ /\/#{disk[:path]}$/ && x.pool_name == poolname
                end.first
                libvirt_disk.destroy if libvirt_disk
              end
            end
          end

          @app.call(env)
        end
      end
    end
  end
end
