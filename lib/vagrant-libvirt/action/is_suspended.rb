module VagrantPlugins
  module Libvirt
    module Action
      # This can be used with "Call" built-in to check if the machine
      # is suspended and branch in the middleware.
      class IsSuspended
        def initialize(app, env)
          @app = app
        end

        def call(env)
          domain = env[:libvirt_compute].servers.get(env[:machine].id.to_s)
          raise Errors::NoDomainError if domain == nil
          env[:result] = domain.state.to_s == 'paused'

          @app.call(env)
        end
      end
    end
  end
end
