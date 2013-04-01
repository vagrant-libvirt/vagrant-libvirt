require 'log4r'

module VagrantPlugins
  module Libvirt
    module Action
      class DestroyDomain
        def initialize(app, env)
          @logger = Log4r::Logger.new("vagrant_libvirt::action::destroy_domain")
          @app = app
        end

        def call(env)
          # Destroy the server, remove the tracking ID
          env[:ui].info(I18n.t("vagrant_libvirt.destroy_domain"))

          domain = env[:libvirt_compute].servers.get(env[:machine].id.to_s)
          domain.destroy(:destroy_volumes => true)
          env[:machine].id = nil

          @app.call(env)
        end
      end
    end
  end
end
