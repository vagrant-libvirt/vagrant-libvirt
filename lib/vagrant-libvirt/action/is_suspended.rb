module VagrantPlugins
  module ProviderLibvirt
    module Action
      # This can be used with "Call" built-in to check if the machine
      # is suspended and branch in the middleware.
      class IsSuspended
        def initialize(app, _env)
          @app = app
        end

        def call(env)
          domain = env[:machine].provider.driver.connection.servers.get(env[:machine].id.to_s)
          raise Errors::NoDomainError if domain.nil?

          config = env[:machine].provider_config
          libvirt_domain = env[:machine].provider.driver.connection.client.lookup_domain_by_uuid(env[:machine].id)
          if config.suspend_mode == 'managedsave'
            if libvirt_domain.has_managed_save?
              env[:result] = env[:machine].state.id == :shutoff
            else
              env[:result] = env[:machine].state.id == :paused
              if env[:result]
                env[:ui].warn('One time switching to pause suspend mode, found a paused VM.')
                config.suspend_mode = 'pause'
              end
            end
          else
            if libvirt_domain.has_managed_save?
              env[:ui].warn('One time switching to managedsave suspend mode, state found.')
              env[:result] = [:shutoff, :paused].include?(env[:machine].state.id)
              config.suspend_mode = 'managedsave'
            else
              env[:result] = env[:machine].state.id == :paused
            end
          end

          @app.call(env)
        end
      end
    end
  end
end
