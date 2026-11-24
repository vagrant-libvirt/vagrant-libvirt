# frozen_string_literal: true

require 'vagrant-libvirt/util/mount_tag'

module VagrantPlugins
  module SyncedFolderVirtioFS
    module Cap
      # Synced folder capabilities allowing Vagrant to persist virtiofs mounts
      # in /etc/fstab, so that they survive a reboot of the guest.
      module MountOptions
        MOUNT_TYPE = 'virtiofs'

        # Returns the mount options for a virtiofs synced folder
        #
        # @param [Machine] machine
        # @param [String] name of mount
        # @param [String] guest_path of mount
        # @param [Hash] options of the synced folder
        # @return [Array<String, nil, nil>] mount options, uid and gid, with the
        #   latter two not applicable as virtiofs maps the host ownership
        def self.mount_options(_machine, _name, _guest_path, options)
          mount_options = Array(options[:mount_options]).dup
          mount_options += options[:mount_opts].split(',') if options[:mount_opts]
          mount_options << 'ro' if options[:readonly]
          # the filesystem device is only attached while the synced folder
          # remains configured, so never let a stale entry block the boot
          mount_options << 'nofail' unless mount_options.include?('nofail')

          [mount_options.join(','), nil, nil]
        end

        # @param [Machine] machine
        # @return [String] filesystem type to mount
        def self.mount_type(_machine)
          MOUNT_TYPE
        end

        # @param [Machine] machine
        # @param [String] name of mount
        # @param [Hash] data of the synced folder
        # @return [String] mount tag the device was attached with
        def self.mount_name(_machine, _name, data)
          data[:mount_tag] || ProviderLibvirt::Util::MountTag.mount_tag(data[:hostpath])
        end
      end
    end
  end
end
