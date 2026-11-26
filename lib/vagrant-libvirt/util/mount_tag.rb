# frozen_string_literal: true

require 'digest/md5'

module VagrantPlugins
  module ProviderLibvirt
    module Util
      module MountTag
        # Libvirt limits the filesystem target dir, which the guest sees as the
        # mount tag, to 31 characters, so derive a stable one from the hostpath.
        def mount_tag(hostpath)
          Digest::MD5.new.update(hostpath).to_s[0, 31]
        end
        module_function :mount_tag
      end
    end
  end
end
