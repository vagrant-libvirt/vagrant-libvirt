require 'nokogiri'
module VagrantPlugins
  module ProviderLibvirt
    module Action
      class PrepareNFSSettings
        include Vagrant::Action::Builtin::MixinSyncedFolders
        
        def initialize(app,env)
          @app = app
          @logger = Log4r::Logger.new("vagrant::action::vm::nfs")
        end

        def call(env)
          @machine = env[:machine]
          @app.call(env)

          if using_nfs?
            @logger.info("Using NFS, preparing NFS settings by reading host IP and machine IP")
            env[:nfs_host_ip]    = read_host_ip(env[:machine],env)
            env[:nfs_machine_ip] = env[:machine].ssh_info[:host]

            @logger.info("host IP: #{env[:nfs_host_ip]} machine IP: #{env[:nfs_machine_ip]}")

            raise Vagrant::Errors::NFSNoHostonlyNetwork if !env[:nfs_machine_ip] || !env[:nfs_host_ip]
          end
        end

        # We're using NFS if we have any synced folder with NFS configured. If
        # we are not using NFS we don't need to do the extra work to
        # populate these fields in the environment.
        def using_nfs?
          !!synced_folders(@machine)[:nfs]
        end

        # Returns the IP address of the first host only network adapter
        #
        # @param [Machine] machine
        # @return [String]
        def read_host_ip(machine,env)
          nets = env[:libvirt_compute].list_networks
          if nets.size == 1
            net = nets.first
          else
            domain = env[:libvirt_compute].servers.get(machine.id.to_s)
            xml=Nokogiri::XML(domain.to_xml)
            networkname = xml.xpath('/domain/devices/interface/source').first.attributes['network'].value.to_s
            puts "network name = #{networkname}"
            net = env[:libvirt_compute].list_networks.find {|netw| netw[:name] == networkname}
          end
          # FIXME better implement by libvirt xml parsing
          if env[:machine].provider_config.nfs_address.nil?
            return `ip addr show | grep -A 2 #{net[:bridge_name]} | grep -i 'inet ' | tr -s ' ' | cut -d' ' -f3 | cut -d'/' -f 1`.chomp
          else
            return env[:machine].provider_config.nfs_address
          end
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
