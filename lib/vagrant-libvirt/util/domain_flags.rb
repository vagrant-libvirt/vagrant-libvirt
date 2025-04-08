 # Ripped from https://libvirt.org/html/libvirt-libvirt-domain.html#types
module VagrantPlugins
  module ProviderLibvirt
    module Util
      module DomainFlags
        # virDomainUndefineFlagsValues
        VIR_DOMAIN_UNDEFINE_MANAGED_SAVE = 1 # Also remove any managed save
        VIR_DOMAIN_UNDEFINE_SNAPSHOTS_METADATA = 2 # If last use of domain, then also remove any snapshot metadata
        VIR_DOMAIN_UNDEFINE_NVRAM = 4 # Also remove any nvram file
        VIR_DOMAIN_UNDEFINE_KEEP_NVRAM = 8 # Keep nvram file
        VIR_DOMAIN_UNDEFINE_CHECKPOINTS_METADATA = 16 # If last use of domain, then also remove any checkpoint metadata Future undefine control flags should come here.
      end
    end
  end
end
