require 'yaml'
module VagrantPlugins
  module ProviderLibvirt
    module Action
      class PruneNFSExports
        def initialize(app, _env)
          @app = app
        end

        def call(env)
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

          @app.call(env)
        end
      end
    end
  end
end
