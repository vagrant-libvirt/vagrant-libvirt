require 'log4r'

module VagrantPlugins
  module ProviderLibvirt
    module Action
      class DestroyDomain
        def initialize(app, env)
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
          libvirt_domain = env[:libvirt_compute].client.lookup_domain_by_uuid(env[:machine].id)
          libvirt_domain.list_snapshots.each do |name|
            @logger.info("Deleting snapshot '#{name}'")
            begin
              libvirt_domain.lookup_snapshot_by_name(name).delete
            rescue => e
              raise Errors::DeleteSnapshotError, error_message: e.message
            end
          end

          domain = env[:libvirt_compute].servers.get(env[:machine].id.to_s)
          domain.destroy(destroy_volumes: true)

          @app.call(env)
        end
      end
    end
  end
end
