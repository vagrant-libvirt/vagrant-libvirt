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

        def initialize(app, env)
          @logger = Log4r::Logger.new("vagrant_libvirt::action::wait_till_up")
          @app = app
        end

        def call(env)
          # Initialize metrics if they haven't been
          env[:metrics] ||= {}

          # Get domain object
          domain = env[:machine].provider.driver.get_domain(env[:machine].id.to_s)
          if domain == nil
            raise Errors::NoDomainError,
              :error_message => "Domain #{env[:machine].id} not found"
          end

          # Wait for domain to obtain an ip address. Ip address is searched
          # from arp table, either localy or remotely via ssh, if libvirt
          # connection was done via ssh.
          env[:ip_address] = nil
          env[:metrics]["instance_ip_time"] = Util::Timer.time do
            @logger.debug("Searching for IP for MAC address: #{domain.mac}")
            env[:ui].info(I18n.t("vagrant_libvirt.waiting_for_ip"))
            retryable(:on => Fog::Errors::TimeoutError, :tries => 300) do
              # If we're interrupted don't worry about waiting
              return terminate(env) if env[:interrupted]

              # Wait for domain to obtain an ip address
              domain.wait_for(2) {
                addresses.each_pair do |type, ip|
                  env[:ip_address] = ip[0] if ip[0] != nil
                end
                env[:ip_address] != nil
              }
            end
          end
          @logger.info("Got IP address #{env[:ip_address]}")
          @logger.info("Time for getting IP: #{env[:metrics]["instance_ip_time"]}")
          
          # Machine has ip address assigned, now wait till we are able to
          # connect via ssh.
          env[:metrics]["instance_ssh_time"] = Util::Timer.time do
            env[:ui].info(I18n.t("vagrant_libvirt.waiting_for_ssh"))
            retryable(:on => Fog::Errors::TimeoutError, :tries => 60) do
              # If we're interrupted don't worry about waiting
              next if env[:interrupted]

              # Wait till we are able to connect via ssh.
              while true
                # If we're interrupted then just back out
                break if env[:interrupted]
                break if env[:machine].communicate.ready?
                sleep 2
              end            
            end
          end
          # if interrupted above, just terminate immediately
          return terminate(env) if env[:interrupted]
          @logger.info("Time for SSH ready: #{env[:metrics]["instance_ssh_time"]}")

          # Booted and ready for use.
          #env[:ui].info(I18n.t("vagrant_libvirt.ready"))
          
          @app.call(env)
        end

        def recover(env)
          return if env["vagrant.error"].is_a?(Vagrant::Errors::VagrantError)

          # Undo the import
          terminate(env)
        end

        def terminate(env)
          if env[:machine].provider.state.id != :not_created
            # If we're not supposed to destroy on error then just return
            return if !env[:destroy_on_error]

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

