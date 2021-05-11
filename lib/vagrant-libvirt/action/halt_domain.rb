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

          if env[:force_halt]
            domain.poweroff
            return @app.call(env)
          end

          begin
            Timeout.timeout(timeout) do
              begin
                env[:machine].guest.capability(:halt)
              rescue Timeout::Error
                raise
              rescue
                @logger.info('Trying Libvirt graceful shutdown.')
                # Read domain object again
                dom = env[:machine].provider.driver.connection.servers.get(env[:machine].id.to_s)
                if dom.state.to_s == 'running'
                  dom.shutdown
                end
              end

              domain.wait_for(timeout) do
                !ready?
              end
            end
          rescue Timeout::Error
            @logger.info('VM is still running. Calling force poweroff.')
            domain.poweroff
          rescue
            @logger.error('Failed to shutdown cleanly. Calling force poweroff.')
            domain.poweroff
          end

          @app.call(env)
        end
      end
    end
  end
end
