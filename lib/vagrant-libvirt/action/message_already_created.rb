module VagrantPlugins
  module ProviderLibvirt
    module Action
      class MessageAlreadyCreated
        def initialize(app, _env)
          @app = app
        end

        def call(env)
          env[:ui].info(I18n.t('vagrant_libvirt.already_created'))
          @app.call(env)
        end
      end
    end
  end
end
