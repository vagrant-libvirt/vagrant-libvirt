module VagrantPlugins
  module ProviderLibvirt
    module Cap
      class NicMacAddresses
        def self.nic_mac_addresses(machine)
          # Vagrant expects a Hash with an index starting at 1 as key
          # and the mac as uppercase string without colons as value
          nic_macs = {}
          machine.provider.mac_addresses.each do |index, mac|
            nic_macs[index + 1] = mac.upcase.delete(':')
          end
          nic_macs
        end
      end
    end
  end
end
