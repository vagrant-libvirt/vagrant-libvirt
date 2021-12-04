# frozen_string_literal: true


module VagrantPlugins
  module ProviderLibvirt
    module Action
      class CleanupOnFailure
        def initialize(app, _env)
          @logger = Log4r::Logger.new('vagrant_libvirt::action::cleanup_on_failure')
          @app = app
        end

        def call(env)
          env['vagrant-libvirt.provider'] = :starting
          @app.call(env)
        end

        def recover(env)
          return unless env[:machine] && env[:machine].state.id != :not_created

          # only destroy if failed to complete bring up
          if env['vagrant-libvirt.provider'] == :finished
            @logger.info("VM completed provider setup, no need to teardown")
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
      end

      class SetupComplete
        def initialize(app, _env)
          @logger = Log4r::Logger.new('vagrant_libvirt::action::cleanup_on_failure')
          @app = app
        end

        def call(env)
          if env['vagrant-libvirt.provider'].nil?
            raise Errors::CallChainError, require_action: CleanupOnFailure.name, current_action: SetupComplete.name
          end

          # mark provider as finished setup so that any failure after this
          # point doesn't result in destroying or shutting down the VM
          env['vagrant-libvirt.provider'] = :finished

          @app.call(env)
        end
      end
    end
  end
end
