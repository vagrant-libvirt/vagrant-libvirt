require 'nokogiri'
require 'socket'
require 'timeout'
require 'vagrant-libvirt/util/nfs'

module VagrantPlugins
  module ProviderLibvirt
    module Action
      class PrepareNFSSettings
        include VagrantPlugins::ProviderLibvirt::Util::Nfs

        def initialize(app, _env)
          @app = app
          @logger = Log4r::Logger.new('vagrant::action::vm::nfs')
        end

        def call(env)
          @machine = env[:machine]
          @app.call(env)

          if using_nfs?
            @logger.info('Using NFS, preparing NFS settings by reading host IP and machine IP')
            env[:nfs_machine_ip] = read_machine_ip(env[:machine])
            env[:nfs_host_ip]    = read_host_ip(env[:nfs_machine_ip])

            @logger.info("host IP: #{env[:nfs_host_ip]} machine IP: #{env[:nfs_machine_ip]}")

            raise Vagrant::Errors::NFSNoHostonlyNetwork if !env[:nfs_machine_ip] || !env[:nfs_host_ip]
          end
        end

        # Returns the IP address of the host
        #
        # @param [Machine] machine
        # @return [String]
        def read_host_ip(ip)
          UDPSocket.open do |s|
            if ip.is_a?(Array)
              s.connect(ip.last, 1)
            else
              s.connect(ip, 1)
            end
            s.addr.last
          end
        end

        # Returns the IP address of the guest
        #
        # @param [Machine] machine
        # @return [String]
        def read_machine_ip(machine)
          # check host only ip
          ssh_host = machine.ssh_info[:host]
          return ssh_host if ping(ssh_host)

          # check other ips
          command = "ip=$(which ip); ${ip:-/sbin/ip} addr show | grep -i 'inet ' | grep -v '127.0.0.1' | tr -s ' ' | cut -d' ' -f3 | cut -d'/' -f 1"
          result  = ''
          machine.communicate.execute(command) do |type, data|
            result << data if type == :stdout
          end

          ips = result.chomp.split("\n").uniq
          @logger.info("guest IPs: #{ips.join(', ')}")
          ips.each do |ip|
            next if ip == ssh_host
            return ip if ping(ip)
          end
        end

        private

        # Check if we can open a connection to the host
        def ping(host, timeout = 3)
          ::Timeout.timeout(timeout) do
            s = TCPSocket.new(host, 'ssh')
            s.close
          end
          true
        rescue Errno::ECONNREFUSED
          true
        rescue Timeout::Error, StandardError
          false
        end
      end
    end
  end
end
