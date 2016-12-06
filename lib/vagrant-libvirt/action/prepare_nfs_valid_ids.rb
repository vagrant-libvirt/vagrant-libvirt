module VagrantPlugins
  module ProviderLibvirt
    module Action
      class PrepareNFSValidIds
        def initialize(app, _env)
          @app = app
          @logger = Log4r::Logger.new('vagrant::action::vm::nfs')
        end

        def call(env)
          env[:nfs_valid_ids] = env[:machine].provider.driver.connection.servers.all.map(&:id)
          @app.call(env)
        end
      end
    end
  end
end
