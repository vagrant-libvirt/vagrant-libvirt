module VagrantPlugins
	module ProviderLibvirt
		module Cap
			class NicMacAddresses
				def self.nic_mac_addresses(machine)
					machine.provider.mac_addresses
				end
			end
		end
	end
end
