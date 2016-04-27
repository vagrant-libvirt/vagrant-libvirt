begin
  require 'vagrant'
rescue LoadError
  raise 'The Vagrant Libvirt plugin must be run within Vagrant.'
end

# compatibility fix to define constant not available vagrant <1.6
::Vagrant::MachineState::NOT_CREATED_ID ||= :not_created

module VagrantPlugins
  module ProviderLibvirt
    class Plugin < Vagrant.plugin('2')
      name 'libvirt'
      description <<-DESC
      Vagrant plugin to manage VMs in libvirt.
      DESC

      config('libvirt', :provider) do
        require_relative 'config'
        Config
      end

      provider('libvirt', parallel: true, box_optional: true) do
        require_relative 'provider'
        Provider
      end

      action_hook(:remove_libvirt_image) do |hook|
        hook.after Vagrant::Action::Builtin::BoxRemove, Action.remove_libvirt_image
      end


      guest_capability('linux', 'mount_p9_shared_folder') do
        require_relative 'cap/mount_p9'
        Cap::MountP9
      end

      provider_capability(:libvirt, :nic_mac_addresses) do
        require_relative "cap/nic_mac_addresses"
        Cap::NicMacAddresses
      end

      # lower priority than nfs or rsync
      # https://github.com/vagrant-libvirt/vagrant-libvirt/pull/170
      synced_folder("9p", 4) do
        require_relative "cap/synced_folder"
        VagrantPlugins::SyncedFolder9p::SyncedFolder
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
        level = nil if !level.is_a?(Integer)

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
