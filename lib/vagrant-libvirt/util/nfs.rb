# frozen_string_literal: true

module VagrantPlugins
  module ProviderLibvirt
    module Util
      module Nfs
        include Vagrant::Action::Builtin::MixinSyncedFolders

        # We're using NFS if we have any synced folder with NFS configured. If
        # we are not using NFS we don't need to do the extra work to
        # populate these fields in the environment.
        def using_nfs?
          !!synced_folders(@machine)[:nfs]
        end
      end
    end
  end
end

