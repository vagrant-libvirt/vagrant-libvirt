
module VagrantPlugins
  module ProviderLibvirt
    module Util
      module StorageUtil
        def storage_uid(env)
          env[:machine].provider_config.qemu_use_session ? Process.uid : 0
        end

        def storage_gid(env)
          env[:machine].provider_config.qemu_use_session ? Process.gid : 0
        end

        def storage_pool_path(env)
          if env[:machine].provider_config.storage_pool_path
            env[:machine].provider_config.storage_pool_path
          elsif env[:machine].provider_config.qemu_use_session
            File.expand_path('~/.local/share/libvirt/images')
          else
            '/var/lib/libvirt/images'
          end
        end
      end
    end
  end
end

