module VagrantPlugins
  module ProviderLibvirt
    module Action
      class MessageNotRunning
        def initialize(app, _env)
          @app = app
        end

        def call(env)
          env[:ui].info(I18n.t('vagrant_libvirt.not_running'))
          @app.call(env)
        end
      end
    end
  end
end
