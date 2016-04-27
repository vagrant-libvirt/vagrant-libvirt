require 'log4r'

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
          # Fog libvirt currently doesn't support snapshots. Use
          # ruby-libvirt client directly. Note this is racy, see
          # http://www.libvirt.org/html/libvirt-libvirt.html#virDomainSnapshotListNames
          libvirt_domain =  env[:machine].provider.driver.connection.client.lookup_domain_by_uuid(
                              env[:machine].id)
          libvirt_domain.list_snapshots.each do |name|
            @logger.info("Deleting snapshot '#{name}'")
            begin
              libvirt_domain.lookup_snapshot_by_name(name).delete
            rescue => e
              raise Errors::DeleteSnapshotError, error_message: e.message
            end
          end

          # must remove managed saves
          if libvirt_domain.has_managed_save?
            libvirt_domain.managed_save_remove
          end

          domain = env[:machine].provider.driver.connection.servers.get(env[:machine].id.to_s)

          if env[:machine].provider_config.disks.empty? and
              env[:machine].provider_config.cdroms.empty?
            # if using default configuration of disks and cdroms
            # cdroms are consider volumes, but cannot be destroyed
            domain.destroy(destroy_volumes: true)
          else
            domain.destroy(destroy_volumes: false)

            env[:machine].provider_config.disks.each do |disk|
              # shared disks remove only manually or ???
              next if disk[:allow_existing]
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
                  # FIXME can remove pool/target.img and pool/123/target.img
                  x.path =~ /\/#{disk[:path]}$/ && x.pool_name == poolname
                end.first
                libvirt_disk.destroy if libvirt_disk
              end
            end

            # remove root storage
            root_disk = domain.volumes.select do |x|
              x.name == libvirt_domain.name + '.img'
            end.first
            root_disk.destroy if root_disk
          end

          @app.call(env)
        end
      end
    end
  end
end
