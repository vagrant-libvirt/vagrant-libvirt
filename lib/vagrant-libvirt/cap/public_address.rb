module VagrantPlugins
  module ProviderLibvirt
    module Cap
      class PublicAddress
        def self.public_address(machine)
          # This does not need to be a globally routable address, it
          # only needs to be accessible from the machine running
          # Vagrant.
          ssh_info = machine.ssh_info
          return nil if !ssh_info
          ssh_info[:host]
        end
      end
    end
  end
end
