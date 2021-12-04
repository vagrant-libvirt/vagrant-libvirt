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

          driver = env[:machine].provider.driver
          domain = driver.get_domain(env[:machine])

          if domain.nil?
            raise Errors::NoDomainError,
                  error_message: "Domain #{env[:machine].id} not found"
          end

          env[:ip_address] = nil
          @logger.debug("Searching for IP for MAC address: #{domain.mac}")
          env[:ui].info(I18n.t('vagrant_libvirt.waiting_for_ip'))

          # Wait for domain to obtain an ip address. Ip address is searched
          # from dhcp leases table via libvirt, or via qemu agent if enabled.
          env[:metrics]['instance_ip_time'] = Util::Timer.time do
            retryable(on: Fog::Errors::TimeoutError, tries: 300) do
              # just return if interrupted and let the warden call recover
              return if env[:interrupted]

              # Wait for domain to obtain an ip address
              env[:ip_address] = driver.get_domain_ipaddress(env[:machine], domain)
            end
          end
          @logger.info("Got IP address #{env[:ip_address]}")
          @logger.info("Time for getting IP: #{env[:metrics]['instance_ip_time']}")

          @app.call(env)
        end
      end
    end
  end
end
