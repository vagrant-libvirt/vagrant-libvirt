module VagrantPlugins
  module ProviderLibvirt
    module Cap
      class ForwardedPorts
        def self.forwarded_ports(machine)
          machine.provider.forwarded_ports
        end
      end
    end
  end
end
