require 'log4r'

module VagrantPlugins
  module ProviderLibvirt
    module Action
      # Halt the domain.
      class HaltDomain
        def initialize(app, _env)
          @logger = Log4r::Logger.new('vagrant_libvirt::action::halt_domain')
          @app = app
        end

        def call(env)
          env[:ui].info(I18n.t('vagrant_libvirt.halt_domain'))

          timeout = env[:machine].config.vm.graceful_halt_timeout
          domain = env[:machine].provider.driver.connection.servers.get(env[:machine].id.to_s)
          raise Errors::NoDomainError if domain.nil?

          begin
            Timeout.timeout(timeout) do
              env[:machine].guest.capability(:halt)
            end
          rescue Timeout::Error
            @logger.info('Trying Libvirt graceful shutdown.')
            # Read domain object again
            dom = env[:machine].provider.driver.connection.servers.get(env[:machine].id.to_s)
            if dom.state.to_s == 'running'
              dom.shutdown
            end
          end

          begin
            domain.wait_for(timeout) do
              !ready?
            end
          rescue Fog::Errors::TimeoutError
            @logger.info('VM is still running. Calling force poweroff.')
            domain.poweroff
          end

          @app.call(env)
        end
      end
    end
  end
end
