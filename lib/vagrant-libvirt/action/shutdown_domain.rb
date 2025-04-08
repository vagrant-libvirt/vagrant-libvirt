require 'log4r'

module VagrantPlugins
  module ProviderLibvirt
    module Action
      # To wrap GracefulShutdown need to track the time taken
      class StartShutdownTimer
        def initialize(app, _env)
          @app = app
        end

        def call(env)
          env[:shutdown_start_time] = Time.now

          @app.call(env)
        end
      end
    end
  end
end

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

          start_time = env[:shutdown_start_time]

          if start_time.nil?
            # this really shouldn't happen
            raise Errors::CallChainError, require_action: StartShutdownTimer.name, current_action: ShutdownDomain.name
          end

          # return if successful, otherwise will ensure result is set to false
          env[:result] = env[:machine].state.id == @target_state

          return @app.call(env) if env[:result]

          current_time = Time.now

          # if we've already exceeded the timeout
          return @app.call(env) if current_time - start_time >= timeout

          # otherwise construct a new timeout.
          timeout = timeout - (current_time - start_time)

          domain = env[:machine].provider.driver.connection.servers.get(env[:machine].id.to_s)
          if env[:machine].state.id == @source_state
            env[:ui].info(I18n.t('vagrant_libvirt.shutdown_domain'))
            domain.shutdown
            begin
                domain.wait_for(timeout) { !ready? }
            rescue Fog::Errors::TimeoutError
            end
          end

          env[:result] = env[:machine].state.id == @target_state

          @app.call(env)
        end
      end
    end
  end
end
