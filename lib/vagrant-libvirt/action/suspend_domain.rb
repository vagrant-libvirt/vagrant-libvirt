require 'log4r'

module VagrantPlugins
  module ProviderLibvirt
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

          domain = env[:machine].provider.driver.connection.servers.get(env[:machine].id.to_s)
          raise Errors::NoDomainError if domain == nil

          config = env[:machine].provider_config
          if config.suspend_mode == 'managedsave'
            libvirt_domain =  env[:machine].provider.driver.connection.client.lookup_domain_by_uuid(env[:machine].id)
            libvirt_domain.managed_save
          else
            domain.suspend
          end

          @logger.info("Machine #{env[:machine].id} is suspended ")

          @app.call(env)
        end
      end
    end
  end
end
