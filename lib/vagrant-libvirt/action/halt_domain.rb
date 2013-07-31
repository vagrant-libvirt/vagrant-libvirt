require 'log4r'

module VagrantPlugins
  module ProviderLibvirt
    module Action
      # Halt the domain.
      class HaltDomain
        def initialize(app, env)
          @logger = Log4r::Logger.new("vagrant_libvirt::action::halt_domain")
          @app = app
        end

        def call(env)
          env[:ui].info(I18n.t("vagrant_libvirt.halt_domain"))

          domain = env[:libvirt_compute].servers.get(env[:machine].id.to_s)
          raise Errors::NoDomainError if domain == nil

          @logger.info("Trying gracefull shutdown.")
          domain.shutdown
          begin
            domain.wait_for(30) {
              !ready?
            }
          rescue Fog::Errors::TimeoutError
            @logger.info("VM is still running. Calling force poweroff.")
            domain.poweroff
          end

          @app.call(env)
        end
      end
    end
  end
end

