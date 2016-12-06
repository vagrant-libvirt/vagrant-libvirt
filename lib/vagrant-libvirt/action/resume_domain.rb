require 'log4r'

module VagrantPlugins
  module ProviderLibvirt
    module Action
      # Resume suspended domain.
      class ResumeDomain
        def initialize(app, _env)
          @logger = Log4r::Logger.new('vagrant_libvirt::action::resume_domain')
          @app = app
        end

        def call(env)
          env[:ui].info(I18n.t('vagrant_libvirt.resuming_domain'))

          domain = env[:machine].provider.driver.connection.servers.get(env[:machine].id.to_s)
          raise Errors::NoDomainError if domain.nil?

          libvirt_domain = env[:machine].provider.driver.connection.client.lookup_domain_by_uuid(env[:machine].id)
          config = env[:machine].provider_config
          if config.suspend_mode == 'managedsave'
            domain.start
          else
            domain.resume
          end

          @logger.info("Machine #{env[:machine].id} is resumed.")

          @app.call(env)
        end
      end
    end
  end
end
