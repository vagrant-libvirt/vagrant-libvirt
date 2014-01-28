require 'vagrant/action/builder'
require 'log4r'

module VagrantPlugins
  module ProviderLibvirt
    module Action
      # Include the built-in modules so we can use them as top-level things.
      include Vagrant::Action::Builtin
      @logger = Log4r::Logger.new('vagrant_libvirt::action') 

      # This action is called to bring the box up from nothing.
      def self.action_up
        Vagrant::Action::Builder.new.tap do |b|
          b.use ConfigValidate
          b.use ConnectLibvirt
          b.use Call, IsCreated do |env, b2|
            # Create VM if not yet created.
            if !env[:result]
              b2.use SetNameOfDomain
              b2.use HandleStoragePool
              b2.use HandleBoxUrl
              b2.use HandleBoxImage
              b2.use CreateDomainVolume
              b2.use CreateDomain

              b2.use TimedProvision
              b2.use CreateNetworks
              b2.use CreateNetworkInterfaces

              b2.use StartDomain
              b2.use WaitTillUp

              if Vagrant::VERSION < "1.4.0"
                b2.use NFS
              else
                b2.use PrepareNFSValidIds
                b2.use SyncedFolderCleanup
                b2.use SyncedFolders
              end

              b2.use PrepareNFSSettings
              b2.use ShareFolders
              b2.use SetHostname
              b2.use SyncFolders
            else
              b2.use action_start
            end
          end
        end
      end

      # Assuming VM is created, just start it. This action is not called
      # directly by any subcommand. VM can be suspended, already running or in
      # poweroff state.
      def self.action_start
        Vagrant::Action::Builder.new.tap do |b|
          b.use ConfigValidate
          b.use ConnectLibvirt
          b.use Call, IsRunning do |env, b2|
            # If the VM is running, then our work here is done, exit
            next if env[:result]

            b2.use Call, IsSuspended do |env2, b3|
              # if vm is suspended resume it then exit
              if env2[:result]
                b3.use ResumeDomain
                next
              end

              # VM is not running or suspended.

              # Ensure networks are created and active
              b3.use CreateNetworks

              # Start it..
              b3.use StartDomain

              # Machine should gain IP address when comming up,
              # so wait for dhcp lease and store IP into machines data_dir.
              b3.use WaitTillUp

              # Handle shared folders
              if Vagrant::VERSION < "1.4.0"
                b3.use NFS
              else
                b3.use PrepareNFSValidIds
                b3.use SyncedFolderCleanup
                b3.use SyncedFolders
              end
              b3.use PrepareNFSSettings
              b3.use ShareFolders

            end
          end
        end
      end

      # This is the action that is primarily responsible for halting the
      # virtual machine.
      def self.action_halt
        Vagrant::Action::Builder.new.tap do |b|
          b.use ConfigValidate
          b.use ConnectLibvirt
          b.use Call, IsCreated do |env, b2|
            if !env[:result]
              b2.use MessageNotCreated
              next
            end

            b2.use Call, IsSuspended do |env2, b3|
              b3.use ResumeDomain if env2[:result]
            end

            b2.use Call, IsRunning do |env2, b3|
              next if !env2[:result]

              # VM is running, halt it.
              b3.use HaltDomain
            end
          end
        end
      end

      # This is the action implements the reload command
      # It uses the halt and start actions
      def self.action_reload
        Vagrant::Action::Builder.new.tap do |b|
          b.use Call, IsCreated do |env, b2|
            if !env[:result]
              b2.use MessageNotCreated
              next
            end

            b2.use ConfigValidate
            b2.use action_halt
            b2.use action_start
          end
        end
      end

      # This is the action that is primarily responsible for completely
      # freeing the resources of the underlying virtual machine.
      def self.action_destroy
        Vagrant::Action::Builder.new.tap do |b|
          b.use ConfigValidate
          b.use Call, IsCreated do |env, b2|
            if !env[:result]
              b2.use MessageNotCreated
              next
            end

            b2.use ConnectLibvirt
            b2.use PruneNFSExports
            b2.use DestroyDomain
            b2.use DestroyNetworks
          end
        end
      end

      # This action is called to SSH into the machine.
      def self.action_ssh
        Vagrant::Action::Builder.new.tap do |b|
          b.use ConfigValidate
          b.use Call, IsCreated do |env, b2|
            if !env[:result]
              b2.use MessageNotCreated
              next
            end

            b2.use ConnectLibvirt
            b2.use Call, IsRunning do |env2, b3|
              if !env2[:result]
                b3.use MessageNotRunning
                next
              end

              b3.use SSHExec
            end
          end
        end
      end

      # This action is called when `vagrant provision` is called.
      def self.action_provision
        Vagrant::Action::Builder.new.tap do |b|
          b.use ConfigValidate
          b.use Call, IsCreated do |env, b2|
            if !env[:result]
              b2.use MessageNotCreated
              next
            end

            b2.use ConnectLibvirt
            b2.use Call, IsRunning do |env2, b3|
              if !env2[:result]
                b3.use MessageNotRunning
                next
              end

              b3.use Provision
              b3.use SyncFolders
            end
          end
        end
      end

      # This is the action that is primarily responsible for suspending
      # the virtual machine.
      def self.action_suspend
        Vagrant::Action::Builder.new.tap do |b|
          b.use ConfigValidate
          b.use Call, IsCreated do |env, b2|
            if !env[:result]
              b2.use MessageNotCreated
              next
            end

            b2.use ConnectLibvirt
            b2.use Call, IsRunning do |env2, b3|
              if !env2[:result]
                b3.use MessageNotRunning
                next
              end
              b3.use SuspendDomain
            end
          end
        end
      end

      # This is the action that is primarily responsible for resuming
      # suspended machines.
      def self.action_resume
        Vagrant::Action::Builder.new.tap do |b|
          b.use ConfigValidate
          b.use Call, IsCreated do |env, b2|
            if !env[:result]
              b2.use MessageNotCreated
              next
            end

            b2.use ConnectLibvirt
            b2.use Call, IsSuspended do |env2, b3|
              if !env2[:result]
                b3.use MessageNotSuspended
                next
              end
              b3.use ResumeDomain
            end
          end
        end
      end

      # This action is called to read the state of the machine. The resulting
      # state is expected to be put into the `:machine_state_id` key.
      def self.action_read_state
        Vagrant::Action::Builder.new.tap do |b|
          b.use ConfigValidate
          b.use ConnectLibvirt
          b.use ReadState
        end
      end

      # This action is called to read the SSH info of the machine. The
      # resulting state is expected to be put into the `:machine_ssh_info`
      # key.
      def self.action_read_ssh_info
        Vagrant::Action::Builder.new.tap do |b|
          b.use ConfigValidate
          b.use ConnectLibvirt
          b.use ReadSSHInfo
        end
      end

      # This is the action that will run a single SSH command.
      def self.action_ssh_run
        Vagrant::Action::Builder.new.tap do |b|
          b.use ConfigValidate
          b.use Call, IsCreated do |env, b2|
            if !env[:result]
              b2.use MessageNotCreated
              next
            end

            b2.use ConnectLibvirt
            b2.use Call, IsRunning do |env2, b3|
              if !env2[:result]
                b3.use MessageNotRunning
                next
              end

              b3.use SSHRun
            end
          end

        end
      end

      action_root = Pathname.new(File.expand_path('../action', __FILE__))
      autoload :ConnectLibvirt, action_root.join('connect_libvirt')
      autoload :CreateDomain, action_root.join('create_domain')
      autoload :CreateDomainVolume, action_root.join('create_domain_volume')
      autoload :CreateNetworkInterfaces, action_root.join('create_network_interfaces')
      autoload :CreateNetworks, action_root.join('create_networks')
      autoload :DestroyDomain, action_root.join('destroy_domain')
      autoload :DestroyNetworks, action_root.join('destroy_networks')
      autoload :HaltDomain, action_root.join('halt_domain')
      autoload :HandleBoxImage, action_root.join('handle_box_image')
      autoload :HandleStoragePool, action_root.join('handle_storage_pool')
      autoload :IsCreated, action_root.join('is_created')
      autoload :IsRunning, action_root.join('is_running')
      autoload :IsSuspended, action_root.join('is_suspended')
      autoload :MessageAlreadyCreated, action_root.join('message_already_created')
      autoload :MessageNotCreated, action_root.join('message_not_created')
      autoload :MessageNotRunning, action_root.join('message_not_running')
      autoload :MessageNotSuspended, action_root.join('message_not_suspended')
      autoload :PrepareNFSSettings, action_root.join('prepare_nfs_settings')
      autoload :PrepareNFSValidIds, action_root.join('prepare_nfs_valid_ids')
      autoload :PruneNFSExports, action_root.join('prune_nfs_exports')
      autoload :ReadSSHInfo, action_root.join('read_ssh_info')
      autoload :ReadState, action_root.join('read_state')
      autoload :ResumeDomain, action_root.join('resume_domain')
      autoload :SetNameOfDomain, action_root.join('set_name_of_domain')
      autoload :ShareFolders, action_root.join('share_folders')
      autoload :StartDomain, action_root.join('start_domain')
      autoload :SuspendDomain, action_root.join('suspend_domain')
      autoload :SyncFolders, action_root.join('sync_folders')
      autoload :TimedProvision, action_root.join('timed_provision')
      autoload :WaitTillUp, action_root.join('wait_till_up')
      autoload :SSHRun,  'vagrant/action/builtin/ssh_run'
      autoload :HandleBoxUrl, 'vagrant/action/builtin/handle_box_url'
      unless Vagrant::VERSION < "1.4.0"
        autoload :SyncedFolders, 'vagrant/action/builtin/synced_folders'
        autoload :SyncedFolderCleanup, 'vagrant/action/builtin/synced_folder_cleanup'
      end
    end
  end
end
