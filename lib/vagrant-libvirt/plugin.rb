# frozen_string_literal: true

begin
  require 'vagrant'
rescue LoadError
  raise 'The Vagrant Libvirt plugin must be run within Vagrant.'
end

require 'vagrant-libvirt/util/compat'

module VagrantPlugins
  module ProviderLibvirt
    class Plugin < Vagrant.plugin('2')
      name 'libvirt'
      description <<-DESC
      Vagrant plugin to manage VMs in Libvirt.
      DESC

      config('libvirt', :provider) do
        require_relative 'config'
        Config
      end

      provider('libvirt', parallel: true, box_optional: true) do
        require_relative 'provider'
        Provider
      end

      action_hook(*(Util::Compat.action_hook_args(:remove_libvirt_image, :box_remove))) do |hook|
        require_relative 'action'
        hook.after Vagrant::Action::Builtin::BoxRemove, Action.remove_libvirt_image
      end

      guest_capability('linux', 'mount_9p_shared_folder') do
        require_relative 'cap/mount_9p'
        Cap::Mount9P
      end
      guest_capability('linux', 'mount_virtiofs_shared_folder') do
        require_relative 'cap/mount_virtiofs'
        Cap::MountVirtioFS
      end
      guest_capability('windows', 'mount_virtiofs_shared_folder') do
        require_relative 'cap/mount_virtiofs'
        Cap::MountVirtioFS
      end

      provider_capability(:libvirt, :nic_mac_addresses) do
        require_relative 'cap/nic_mac_addresses'
        Cap::NicMacAddresses
      end

      provider_capability(:libvirt, :public_address) do
        require_relative 'cap/public_address'
        Cap::PublicAddress
      end

      provider_capability(:libvirt, :snapshot_list) do
        require_relative 'cap/snapshots'
        Cap::Snapshots
      end

      # lower priority than nfs or rsync
      # https://github.com/vagrant-libvirt/vagrant-libvirt/pull/170
      synced_folder('9p', 4) do
        require_relative 'cap/synced_folder_9p'
        VagrantPlugins::SyncedFolder9P::SyncedFolder
      end
      synced_folder('virtiofs', 5) do
        require_relative 'cap/synced_folder_virtiofs'
        VagrantPlugins::SyncedFolderVirtioFS::SyncedFolder
      end

      # This initializes the internationalization strings.
      def self.setup_i18n
        I18n.load_path << File.expand_path('locales/en.yml',
                                           ProviderLibvirt.source_root)
        I18n.reload!
      end

      # This sets up our log level to be whatever VAGRANT_LOG is.
      def self.setup_logging
        require 'log4r'

        level = nil
        begin
          level = Log4r.const_get(ENV['VAGRANT_LOG'].upcase)
        rescue NameError
          # This means that the logging constant wasn't found,
          # which is fine. We just keep `level` as `nil`. But
          # we tell the user.
          level = nil
        end

        # Some constants, such as "true" resolve to booleans, so the
        # above error checking doesn't catch it. This will check to make
        # sure that the log level is an integer, as Log4r requires.
        level = nil unless level.is_a?(Integer)

        # Set the logging level on all "vagrant" namespaced
        # logs as long as we have a valid level.
        if level
          logger = Log4r::Logger.new('vagrant_libvirt')
          logger.outputters = Log4r::Outputter.stderr
          logger.level = level
          logger = nil
        end
      end

      # Setup logging and i18n before any autoloading loads other classes
      # with logging configured as this prevents inheritance of the log level
      # from the parent logger.
      setup_logging
      setup_i18n
    end
  end
end
