# frozen_string_literal: true

require 'vagrant-libvirt/util/mount_tag'

module VagrantPlugins
  module SyncedFolder9P
    module Cap
      # Synced folder capabilities allowing Vagrant to persist 9p mounts in
      # /etc/fstab, so that they survive a reboot of the guest.
      module MountOptions
        MOUNT_TYPE = '9p'
        # the version the synced folder mounts with by default, see
        # VagrantPlugins::SyncedFolder9P::SyncedFolder#enable
        DEFAULT_VERSION = '9p2000.L'
        # what the 9p client takes as an access mode besides a uid, see
        # `v9fs_parse_options` of the kernel
        ACCESS_MODES = %w[user any client].freeze

        # Returns the mount options for a 9p synced folder
        #
        # @param [Machine] machine
        # @param [String] name of mount
        # @param [String] guest_path of mount
        # @param [Hash] options of the synced folder
        # @return [Array<String, nil, nil>] mount options, uid and gid, with the
        #   latter two not applicable as 9p maps the ownership itself
        def self.mount_options(_machine, _name, _guest_path, options)
          # the filesystem device is attached to the virtio bus, see
          # VagrantPlugins::ProviderLibvirt::Cap::Mount9P
          mount_options = ['trans=virtio']
          mount_options += Array(options[:mount_options])

          access = access_mode(options)
          mount_options << "access=#{access}" if access

          mount_options << "version=#{options[:version] || DEFAULT_VERSION}"
          mount_options += options[:mount_opts].split(',') if options[:mount_opts]
          mount_options << 'ro' if options[:readonly]
          # a share Vagrant was asked not to mount must not be mounted by the
          # guest on its own either, see SyncedFolder#enable
          mount_options << 'noauto' if options[:mount] == false
          # the filesystem device is only attached while the synced folder
          # remains configured, so never let a stale entry block the boot
          mount_options << 'nofail'

          [mount_options.uniq.join(','), nil, nil]
        end

        # The access mode to mount the synced folder with, if any.
        #
        # The deprecation of `:owner` in favour of `:access` is reported while
        # mounting, so the fallback to it is silent here. It has to ignore
        # everything the 9p client would not take, because Vagrant fills
        # `:owner` in with the user it connects as before it renders the
        # options into /etc/fstab, see the `persist_mount_shared_folder`
        # capability of its linux guest. An entry carrying that username is
        # rejected by the client with `Unknown access argument`, and as the
        # entry is written with `nofail`, the share would silently stay
        # unmounted after a reboot of the guest.
        #
        # @param [Hash] options of the synced folder
        # @return [String, nil] access mode
        def self.access_mode(options)
          return options[:access].to_s if options[:access]

          owner = options[:owner]&.to_s
          return owner if ACCESS_MODES.include?(owner) || owner =~ /\A\d+\z/

          nil
        end
        private_class_method :access_mode

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
