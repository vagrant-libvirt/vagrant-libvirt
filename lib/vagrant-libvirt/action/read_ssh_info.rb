require "log4r"

module VagrantPlugins
  module Libvirt
    module Action
      # This action reads the SSH info for the machine and puts it into the
      # `:machine_ssh_info` key in the environment.
      class ReadSSHInfo
        def initialize(app, env)
          @app    = app
          @logger = Log4r::Logger.new("vagrant_libvirt::action::read_ssh_info")
        end

        def call(env)
          env[:machine_ssh_info] = read_ssh_info(
            env[:libvirt_compute], env[:machine])

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

          # Return the info
          # TODO: Some info should be configurable in Vagrantfile
          return {
            :host          => ip_address,
            :port          => 22,
            :username      => 'root',
            :forward_agent => true,
            :forward_x11   => true,
          }
        end 
      end
    end
  end
end
