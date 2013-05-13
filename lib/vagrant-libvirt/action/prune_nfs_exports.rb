require 'yaml'
module VagrantPlugins
  module Libvirt
    module Action
      class PruneNFSExports

        def initialize(app, env)
          @app = app
        end

        def call(env)
          if env[:host]
            uuid = env[:machine].id
            # get all uuids
            uuids = env[:libvirt_compute].servers.all.map(&:id)
            # not exiisted in array will removed from nfs
            uuids.delete(uuid)
            env[:host].nfs_prune(uuids)
          end

          @app.call(env)
        end
      end
    end
  end
end
