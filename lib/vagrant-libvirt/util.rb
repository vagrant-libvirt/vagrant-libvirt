module VagrantPlugins
  module ProviderLibvirt
    module Util
      autoload :ErbTemplate, 'vagrant-libvirt/util/erb_template'
      autoload :Collection,  'vagrant-libvirt/util/collection'
      autoload :Timer, 'vagrant-libvirt/util/timer'
      autoload :NetworkUtil, 'vagrant-libvirt/util/network_util'
      autoload :StorageUtil, 'vagrant-libvirt/util/storage_util'
      autoload :ErrorCodes, 'vagrant-libvirt/util/error_codes'
    end
  end
end
