require 'log4r'

module VagrantPlugins
  module ProviderLibvirt
    module Action
      # Shutdown the domain.
      class ShutdownDomain
        def initialize(app, _env, target_state, source_state)
          @logger = Log4r::Logger.new('vagrant_libvirt::action::shutdown_domain')
          @target_state = target_state
          @source_state = source_state
          @app = app
        end

        def call(env)
          timeout = env[:machine].config.vm.graceful_halt_timeout
          domain = env[:machine].provider.driver.connection.servers.get(env[:machine].id.to_s)
          if env[:machine].state.id == @source_state
            env[:ui].info(I18n.t('vagrant_libvirt.shutdown_domain'))
            domain.shutdown
            domain.wait_for(timeout) { !ready? }
          end

          env[:result] = env[:machine].state.id == @target_state

          @app.call(env)
        end
      end
    end
  end
end
