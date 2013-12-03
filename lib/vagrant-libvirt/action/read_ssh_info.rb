require "log4r"

module VagrantPlugins
  module ProviderLibvirt
    module Action
      # This action reads the SSH info for the machine and puts it into the
      # `:machine_ssh_info` key in the environment.
      class ReadSSHInfo
        def initialize(app, env)
          @app    = app
          @logger = Log4r::Logger.new("vagrant_libvirt::action::read_ssh_info")
        end

        def call(env)
          env[:machine_ssh_info] = read_ssh_info(env[:libvirt_compute],
                                                 env[:machine])

          @app.call(env)
        end

        def read_ssh_info(libvirt, machine)
          return nil if machine.id.nil?

          # Find the machine
          domain = libvirt.servers.get(machine.id)
          if domain.nil?
            # The machine can't be found
            @logger.info("Machine couldn't be found, assuming it got destroyed.")
            machine.id = nil
            return nil
          end

          # Get IP address from dnsmasq lease file.
          ip_address = nil
          domain.wait_for(2) {
            addresses.each_pair do |type, ip|
              ip_address = ip[0] if ip[0] != nil
            end
            ip_address != nil
          }
          raise Errors::NoIpAddressError if not ip_address

          ssh_info = {
            :host          => ip_address,
            :port          => machine.config.ssh.guest_port,
            :username      => machine.config.ssh.username,
            :forward_agent => machine.config.ssh.forward_agent,
            :forward_x11   => machine.config.ssh.forward_x11,
          }
          
          ssh_info[:proxy_command] = "ssh '#{machine.provider_config.host}' -l '#{machine.provider_config.username}' nc %h %p" if machine.provider_config.connect_via_ssh

          if not ssh_info[:username]
            ssh_info[:username] = machine.config.ssh.default.username
          end

          ssh_info
        end
      end
    end
  end
end
