# frozen_string_literal: true

require 'digest/md5'
require 'vagrant/util/retryable'

module VagrantPlugins
  module ProviderLibvirt
    module Cap
      class Mount9P
        extend Vagrant::Util::Retryable

        def self.mount_9p_shared_folder(machine, folders)
          folders.each do |_name, opts|
            # Expand the guest path so we can handle things like "~/vagrant"
            expanded_guest_path = machine.guest.capability(
              :shell_expand_guest_path, opts[:guestpath]
            )

            # Do the actual creating and mounting
            machine.communicate.sudo("mkdir -p #{expanded_guest_path}")

            # Mount
            mount_tag = Digest::MD5.new.update(opts[:hostpath]).to_s[0, 31]

            mount_opts = '-o trans=virtio'
            mount_opts += ",access=#{opts[:access]}" if opts[:access]
            if opts[:owner]
              if opts[:access]
                machine.ui.warn('deprecated `:owner` option ignored as replacement `:access` option already set, please update your Vagrantfile and remove the `:owner` option to prevent this warning.')
              else
                machine.ui.warn('`:owner` option for 9p mount options deprecated in favour of `:access`, please update your Vagrantfile and replace `:owner` with `:access`')
                mount_opts += ",access=#{opts[:owner]}"
              end
            end
            mount_opts += ",version=#{opts[:version]}" if opts[:version]
            mount_opts += ",#{opts[:mount_opts]}" if opts[:mount_opts]

            mount_command = "mount -t 9p #{mount_opts} '#{mount_tag}' #{expanded_guest_path}"
            retryable(on: Vagrant::Errors::LinuxMountFailed,
                      tries: 5,
                      sleep: 3) do
              machine.communicate.sudo('modprobe 9p')
              machine.communicate.sudo('modprobe 9pnet_virtio')
              machine.communicate.sudo(mount_command,
                                       error_class: Vagrant::Errors::LinuxMountFailed)
            end
          end
        end
      end
    end
  end
end
