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
          server = libvirt.servers.get(machine.id)
          if server.nil?
            # The machine can't be found
            @logger.info("Machine couldn't be found, assuming it got destroyed.")
            machine.id = nil
            return nil
          end

          # Get ip address of machine
          ip_address = server.public_ip_address
          ip_address = server.private_ip_address if ip_address == nil
          return nil if ip_address == nil

          # Return the info
          # TODO: Some info should be configurable in Vagrantfile
          return {
            :host => ip_address,
            :port => 22,
            :username => 'root',
          }
        end
 
      end
    end
  end
end
