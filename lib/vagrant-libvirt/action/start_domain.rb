require 'log4r'

module VagrantPlugins
  module Libvirt
    module Action

      # Just start the domain.
      class StartDomain
        def initialize(app, env)
          @logger = Log4r::Logger.new("vagrant_libvirt::action::start_domain")
          @app = app
        end

        def call(env)
          env[:ui].info(I18n.t("vagrant_libvirt.starting_domain"))

          domain = env[:libvirt_compute].servers.get(env[:machine].id.to_s)
          raise Errors::NoDomainError if domain == nil
          domain.start

          @app.call(env)
        end
      end

    end
  end
end
