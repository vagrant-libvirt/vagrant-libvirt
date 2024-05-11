# frozen_string_literal: true

# Ripped from https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainModificationImpact
module VagrantPlugins
  module ProviderLibvirt
    module Util
      module ModImpactFlags
        VIR_DOMAIN_AFFECT_CURRENT = 0 # affect current domain state
        VIR_DOMAIN_AFFECT_LIVE = 1 # affect running domain state
        VIR_DOMAIN_AFFECT_CONFIG = 2 # affect persistent domain state
      end
    end
  end
end
