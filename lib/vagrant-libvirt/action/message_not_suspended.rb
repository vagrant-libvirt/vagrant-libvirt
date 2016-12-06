module VagrantPlugins
  module ProviderLibvirt
    module Action
      class MessageNotSuspended
        def initialize(app, _env)
          @app = app
        end

        def call(env)
          env[:ui].info(I18n.t('vagrant_libvirt.not_suspended'))
          @app.call(env)
        end
      end
    end
  end
end
