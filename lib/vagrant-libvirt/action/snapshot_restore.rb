# frozen_string_literal: true

module VagrantPlugins
  module ProviderLibvirt
    module Action
      class SnapshotRestore
        def initialize(app, env)
          @app = app
        end

        def call(env)
          env[:ui].info(I18n.t(
            "vagrant.actions.vm.snapshot.restoring",
            name: env[:snapshot_name]))
          env[:machine].provider.driver.restore_snapshot(env[:machine], env[:snapshot_name])

          @app.call(env)
        end
      end
    end
  end
end
