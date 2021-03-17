require 'vagrant-libvirt/util/nfs'
require 'yaml'

module VagrantPlugins
  module ProviderLibvirt
    module Action
      class PruneNFSExports
        include VagrantPlugins::ProviderLibvirt::Util::Nfs

        def initialize(app, _env)
          @logger = Log4r::Logger.new('vagrant_libvirt::action::prune_nfs_exports')
          @app = app
        end

        def call(env)
          @machine = env[:machine]

          if using_nfs?
            @logger.info('Using NFS, prunning NFS settings from host')
            if env[:host]
              uuid = env[:machine].id
              # get all uuids
              uuids = env[:machine].provider.driver.connection.servers.all.map(&:id)
              # not exiisted in array will removed from nfs
              uuids.delete(uuid)
              env[:host].capability(
                :nfs_prune, env[:machine].ui, uuids
              )
            end
          end

          @app.call(env)
        end
      end
    end
  end
end
