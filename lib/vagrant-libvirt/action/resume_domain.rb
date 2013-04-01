require 'log4r'

module VagrantPlugins
  module Libvirt
    module Action
      # Resume suspended domain.
      class ResumeDomain
        def initialize(app, env)
          @logger = Log4r::Logger.new("vagrant_libvirt::action::resume_domain")
          @app = app
        end

        def call(env)
          env[:ui].info(I18n.t("vagrant_libvirt.resuming_domain"))

          domain = env[:libvirt_compute].servers.get(env[:machine].id.to_s)
          raise Errors::NoDomainError if domain == nil

          domain.resume
          @logger.info("Machine #{env[:machine].id} is resumed.")

          @app.call(env)
        end
      end
    end
  end
end
