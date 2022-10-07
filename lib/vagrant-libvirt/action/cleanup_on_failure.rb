# frozen_string_literal: true


module VagrantPlugins
  module ProviderLibvirt
    module Action
      class CleanupOnFailure
        def initialize(app, _env)
          @logger = Log4r::Logger.new('vagrant_libvirt::action::cleanup_on_failure')
          @app = app
          @cleanup = true
        end

        def call(env)
          # passing a value doesn't work as the env that is updated may be dupped from
          # the original meaning the latter action's update is discarded. Instead pass
          # a reference to the method on this class that will toggle the instance
          # variable indicating whether cleanup is needed or not.
          env['vagrant-libvirt.complete'] = method(:completed)

          @app.call(env)
        end

        def recover(env)
          return unless env[:machine] && env[:machine].state.id != :not_created

          # only destroy if failed to complete bring up
          unless @cleanup
            @logger.debug('VM provider setup was completed, no need to halt/destroy')
            return
          end

          # If we're not supposed to destroy on error then just return
          return unless env[:destroy_on_error]

          if env[:halt_on_error]
            halt_env = env.dup
            halt_env.delete(:interrupted)
            halt_env[:config_validate] = false
            env[:action_runner].run(Action.action_halt, halt_env)
          else
            destroy_env = env.dup
            destroy_env.delete(:interrupted)
            destroy_env[:config_validate] = false
            destroy_env[:force_confirm_destroy] = true
            env[:action_runner].run(Action.action_destroy, destroy_env)
          end
        end

        def completed
          @cleanup = false
        end
      end

      class SetupComplete
        def initialize(app, _env)
          @logger = Log4r::Logger.new('vagrant_libvirt::action::setup_complete')
          @app = app
        end

        def call(env)
          if env['vagrant-libvirt.complete'].nil? or !env['vagrant-libvirt.complete'].respond_to? :call
            raise Errors::CallChainError, require_action: CleanupOnFailure.name, current_action: SetupComplete.name
          end

          @logger.debug('Marking provider setup as completed')
          # mark provider as finished setup so that any failure after this
          # point doesn't result in destroying or shutting down the VM
          env['vagrant-libvirt.complete'].call

          @app.call(env)
        end
      end
    end
  end
end
