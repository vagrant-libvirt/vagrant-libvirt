# frozen_string_literal: true

require 'log4r'
require 'vagrant-libvirt/errors'
require 'vagrant-libvirt/util/timer'
require 'vagrant/util/retryable'

module VagrantPlugins
  module ProviderLibvirt
    module Action
      # Wait till domain is started, till it obtains an IP address and is
      # accessible via ssh.
      class WaitTillUp
        include Vagrant::Util::Retryable

        def initialize(app, _env)
          @logger = Log4r::Logger.new('vagrant_libvirt::action::wait_till_up')
          @app = app
        end

        def call(env)
          # Initialize metrics if they haven't been
          env[:metrics] ||= {}

          # Get domain object
          domain = env[:machine].provider.driver.get_domain(env[:machine])
          if domain.nil?
            raise Errors::NoDomainError,
                  error_message: "Domain #{env[:machine].id} not found"
          end

          # Wait for domain to obtain an ip address. Ip address is searched
          # from arp table, either locally or remotely via ssh, if Libvirt
          # connection was done via ssh.
          env[:ip_address] = nil
          @logger.debug("Searching for IP for MAC address: #{domain.mac}")
          env[:ui].info(I18n.t('vagrant_libvirt.waiting_for_ip'))

          env[:metrics]['instance_ip_time'] = Util::Timer.time do
            retryable(on: Fog::Errors::TimeoutError, tries: 300) do
              # just return if interrupted and let the warden call recover
              return if env[:interrupted]

              # Wait for domain to obtain an ip address
              env[:ip_address] = env[:machine].provider.driver.get_domain_ipaddress(env[:machine], domain)
            end
          end

          @logger.info("Got IP address #{env[:ip_address]}")
          @logger.info("Time for getting IP: #{env[:metrics]['instance_ip_time']}")

          @app.call(env)
        end

        def recover(env)
          # Undo the import
          terminate(env)
        end

        def terminate(env)
          if env[:machine].state.id != :not_created
            # If we're not supposed to destroy on error then just return
            return unless env[:destroy_on_error]

            if env[:halt_on_error]
              halt_env = env.dup
              halt_env.delete(:interrupted)
              halt_env[:config_validate] = false
              env[:action_runner].run(Action.action_halt, halt_env)
            else
              destroy_env = env.dup
              destroy_env.delete(:interrupted)
              destroy_env[:config_validate] = false
              destroy_env[:force_confirm_destroy] = true
              env[:action_runner].run(Action.action_destroy, destroy_env)
            end
          end
        end
      end
    end
  end
end
