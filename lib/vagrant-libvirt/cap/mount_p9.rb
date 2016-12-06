require 'digest/md5'
require 'vagrant/util/retryable'

module VagrantPlugins
  module ProviderLibvirt
    module Cap
      class MountP9
        extend Vagrant::Util::Retryable

        def self.mount_p9_shared_folder(machine, folders)
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
            mount_opts += ",access=#{opts[:owner]}" if opts[:owner]
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
