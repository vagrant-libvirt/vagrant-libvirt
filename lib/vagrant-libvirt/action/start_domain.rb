require 'log4r'

module VagrantPlugins
  module ProviderLibvirt
    module Action

      # Just start the domain.
      class StartDomain
        def initialize(app, env)
          @logger = Log4r::Logger.new("vagrant_libvirt::action::start_domain")
          @app = app
        end

        def call(env)
          env[:ui].info(I18n.t("vagrant_libvirt.starting_domain"))

          domain = env[:machine].provider.driver.connection.servers.get(env[:machine].id.to_s)
          raise Errors::NoDomainError if domain == nil

          begin
            domain.start
          rescue => e
            raise Errors::FogError, :message => e.message
          end

          @app.call(env)
        end
      end

    end
  end
end
