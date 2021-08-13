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

          start_time = Time.now

          # call nested action first under the assumption it should try to
          # handle shutdown via client capabilities
          @app.call(env)

          # return if successful, otherwise will ensure result is set to false
          env[:result] = env[:machine].state.id == @target_state

          return if env[:result]

          current_time = Time.now

          # if we've already exceeded the timeout
          return if current_time - start_time >= timeout

          # otherwise construct a new timeout.
          timeout = timeout - (current_time - start_time)

          domain = env[:machine].provider.driver.connection.servers.get(env[:machine].id.to_s)
          if env[:machine].state.id == @source_state
            env[:ui].info(I18n.t('vagrant_libvirt.shutdown_domain'))
            domain.shutdown
            domain.wait_for(timeout) { !ready? }
          end

          env[:result] = env[:machine].state.id == @target_state
        end
      end
    end
  end
end
