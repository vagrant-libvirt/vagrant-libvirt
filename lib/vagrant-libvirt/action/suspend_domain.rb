require 'log4r'

module VagrantPlugins
  module Libvirt
    module Action
      # Suspend domain.
      class SuspendDomain
        def initialize(app, env)
          @logger = Log4r::Logger.new("vagrant_libvirt::action::suspend_domain")
          @app = app
        end

        # make pause
        def call(env)
          env[:ui].info(I18n.t("vagrant_libvirt.suspending_domain"))

          domain = env[:libvirt_compute].servers.get(env[:machine].id.to_s)
          raise Errors::NoDomainError if domain == nil

          domain.suspend
          @logger.info("Machine #{env[:machine].id} is suspended ")

          @app.call(env)
        end
      end
    end
  end
end
