module VagrantPlugins
  module Libvirt
    module Action
      class PrepareNFSSettings
        def initialize(app,env)
          @app = app
          @logger = Log4r::Logger.new("vagrant::action::vm::nfs")
        end

        def call(env)
          @app.call(env)

          using_nfs = false
          env[:machine].config.vm.synced_folders.each do |id, opts|
            if opts[:nfs]
              using_nfs = true
              break
            end
          end

          if using_nfs
            @logger.info("Using NFS, preparing NFS settings by reading host IP and machine IP")
            env[:nfs_host_ip]    = read_host_ip(env[:machine])
            env[:nfs_machine_ip] = env[:machine].ssh_info[:host]

            raise Vagrant::Errors::NFSNoHostonlyNetwork if !env[:nfs_machine_ip]
          end
        end

        # Returns the IP address of the first host only network adapter
        #
        # @param [Machine] machine
        # @return [String]
        def read_host_ip(machine)
          `ip addr show | grep -A 2 virbr0 | grep -i 'inet ' | tr -s ' ' | cut -d' ' -f3 | cut -d'/' -f 1`.chomp
        end

        # Returns the IP address of the guest by looking at the first
        # enabled host only network.
        #
        # @return [String]
        def read_machine_ip(machine)
          machine.config.vm.networks.each do |type, options|
            if type == :private_network && options[:ip].is_a?(String)
              return options[:ip]
            end
          end

          nil
        end
      end
    end
  end
end
