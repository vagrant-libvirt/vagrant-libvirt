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

        def read_ssh_info(libvirt,machine)
          return nil if machine.id.nil?

          # Find the machine
          domain = libvirt.servers.get(machine.id)
          if domain.nil?
            # The machine can't be found
            @logger.info("Machine couldn't be found, assuming it got destroyed.")
            machine.id = nil
            return nil
          end

          # IP address of machine is stored in $data_dir/ip file. Why? Commands
          # like ssh or provision need to get IP of VM long time after it was
          # started and gathered IP. Record in arp table is lost, and this is
          # the way how to store this info. Not an ideal solution, but libvirt
          # doesn't provide way how to get IP of some domain. 
          ip_file = machine.data_dir + 'ip'
          raise Errors::NoIpAddressError if not File.exists?(ip_file)
          ip_address = File.open(ip_file, 'r') do |file|
            file.read
          end

          # Check if stored IP address matches with MAC address of machine.
          # Command is executed either localy, or on remote libvirt hypervisor,
          # depends on establised fog libvirt connection.
          ip_match = false
          ip_command = "ping -c1 #{ip_address} > /dev/null && "
          ip_command << "arp -an | grep $mac | sed '"
          ip_command << 's/.*(\([0-9\.]*\)).*/\1/' + "'"
          options_hash = { :ip_command => ip_command }
          3.times do |x|
            break if ip_match
            domain.wait_for(1) {
              begin
                addresses(service, options_hash).each_pair do |type, ip|
                  if ip[0] != nil
                    ip_match = true
                    break
                  end
                end
              rescue Fog::Errors::Error
                # Sometimes, if pinging happen too quickly after after IP
                # assignment, machine is not responding yet. Give it a little
                # time..
                sleep 1
              end

              break if ip_match
            }
          end
          raise Errors::IpAddressMismatchError if not ip_match

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
