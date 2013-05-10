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
            env[:host].nfs_prune(uuid)
          end

          @app.call(env)
        end
      end
    end
  end
end
