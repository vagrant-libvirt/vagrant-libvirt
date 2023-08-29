# frozen_string_literal: true

require 'vagrant/action/builder'
require 'log4r'

module VagrantPlugins
  module ProviderLibvirt
    module Action
      action_root = Pathname.new(File.expand_path('../action', __FILE__))
      autoload :CleanupOnFailure, action_root.join('cleanup_on_failure')
      autoload :ClearForwardedPorts, action_root.join('forward_ports')
      autoload :CreateDomain, action_root.join('create_domain')
      autoload :CreateDomainVolume, action_root.join('create_domain_volume')
      autoload :CreateNetworkInterfaces, action_root.join('create_network_interfaces')
      autoload :CreateNetworks, action_root.join('create_networks')
      autoload :CleanMachineFolder, action_root.join('clean_machine_folder')
      autoload :DestroyDomain, action_root.join('destroy_domain')
      autoload :DestroyNetworks, action_root.join('destroy_networks')
      autoload :ForwardPorts, action_root.join('forward_ports')
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
      autoload :MessageWillNotDestroy, action_root.join('message_will_not_destroy')
      autoload :PackageDomain, action_root.join('package_domain')
      autoload :PrepareNFSSettings, action_root.join('prepare_nfs_settings')
      autoload :PrepareNFSValidIds, action_root.join('prepare_nfs_valid_ids')
      autoload :PruneNFSExports, action_root.join('prune_nfs_exports')
      autoload :ReadMacAddresses, action_root.join('read_mac_addresses')
      autoload :RemoveLibvirtImage, action_root.join('remove_libvirt_image')
      autoload :RemoveStaleVolume, action_root.join('remove_stale_volume')
      autoload :ResolveDiskSettings, action_root.join('resolve_disk_settings')
      autoload :ResumeDomain, action_root.join('resume_domain')
      autoload :SetNameOfDomain, action_root.join('set_name_of_domain')
      autoload :SetBootOrder, action_root.join('set_boot_order')
      autoload :SetupComplete, action_root.join('cleanup_on_failure')
      # Snapshot autoload
      autoload :SnapshotDelete, action_root.join('snapshot_delete')
      autoload :SnapshotSave, action_root.join('snapshot_save')
      autoload :SnapshotRestore, action_root.join('snapshot_restore')


      # I don't think we need it anymore
      autoload :ShareFolders, action_root.join('share_folders')
      autoload :ShutdownDomain, action_root.join('shutdown_domain')
      autoload :StartDomain, action_root.join('start_domain')
      autoload :StartShutdownTimer, action_root.join('shutdown_domain')
      autoload :SuspendDomain, action_root.join('suspend_domain')
      autoload :WaitTillUp, action_root.join('wait_till_up')

      autoload :Package, 'vagrant/action/general/package'
      autoload :PackageSetupFiles, 'vagrant/action/general/package_setup_files'
      autoload :PackageSetupFolders, 'vagrant/action/general/package_setup_folders'
      autoload :ProvisionerCleanup, 'vagrant/action/builtin/provisioner_cleanup'
      autoload :SSHRun, 'vagrant/action/builtin/ssh_run'
      autoload :SyncedFolderCleanup, 'vagrant/action/builtin/synced_folder_cleanup'

      # Include the built-in & general modules so we can use them as top-level things.
      include Vagrant::Action::Builtin
      include Vagrant::Action::General
      @logger = Log4r::Logger.new('vagrant_libvirt::action')

      # remove image from Libvirt storage pool
      def self.remove_libvirt_image
        Vagrant::Action::Builder.new.tap do |b|
          b.use RemoveLibvirtImage
        end
      end

      # This action is called to bring the box up from nothing.
      def self.action_up
        Vagrant::Action::Builder.new.tap do |b|
          b.use ConfigValidate
          b.use BoxCheckOutdated
          b.use Call, IsCreated do |env, b2|
            b2.use CleanupOnFailure
            b2.use Provision

            # Create VM if not yet created.
            if !env[:result]
              b2.use SetNameOfDomain

              if !env[:machine].config.vm.box
                b2.use ResolveDiskSettings
                b2.use CreateDomain
                b2.use CreateNetworks
                b2.use CreateNetworkInterfaces

                b2.use action_start
              else
                b2.use HandleStoragePool
                require 'vagrant/action/builtin/handle_box'
                b2.use HandleBox
                b2.use HandleBoxImage
                b2.use CreateDomainVolume
                b2.use ResolveDiskSettings
                b2.use CreateDomain
                b2.use CreateNetworks
                b2.use CreateNetworkInterfaces

                b2.use action_start

                b2.use SetHostname
              end
            else
              # start VM if halted
              env[:halt_on_error] = true
              b2.use ResolveDiskSettings
              b2.use CreateNetworks
              b2.use action_start
            end

            # corresponding action to CleanupOnFailure
            b2.use SetupComplete
          end
        end
      end

      # Assuming VM is created, just start it. This action is not called
      # directly by any subcommand. VM can be suspended, already running or in
      # poweroff state.
      private_class_method def self.action_start
        Vagrant::Action::Builder.new.tap do |b|
          b.use Call, IsRunning do |env, b2|
            if env[:result]
              next
            end

            b2.use Call, IsSuspended do |env2, b3|
              # if vm is suspended resume it
              if env2[:result]
                b3.use ResumeDomain

                # if there was a box, want to wait until the communicator is
                # available and then forward ports
                next if !env[:machine].config.vm.box
              elsif !env[:machine].config.vm.box
                # With no box, we just care about network creation and starting it
                b3.use SetBootOrder
                b3.use StartDomain

                next
              else
                # VM is not running or suspended.
                b3.use PrepareNFSValidIds
                b3.use SyncedFolderCleanup
                require 'vagrant/action/builtin/synced_folders'
                b3.use SyncedFolders
                b3.use PrepareNFSSettings
                b3.use ShareFolders

                b3.use SetBootOrder

                # Start it..
                b3.use StartDomain

                # Machine should gain IP address when coming up,
                # so wait for dhcp lease and store IP into machines data_dir.
                b3.use WaitTillUp
              end

              require 'vagrant/action/builtin/wait_for_communicator'
              b3.use WaitForCommunicator, [:running]

              b3.use ForwardPorts
            end
          end
        end
      end

      # This is the action that is primarily responsible for halting the
      # virtual machine.
      def self.action_halt
        Vagrant::Action::Builder.new.tap do |b|
          b.use ConfigValidate
          b.use ClearForwardedPorts
          b.use Call, IsCreated do |env, b2|
            unless env[:result]
              b2.use MessageNotCreated
              next
            end

            b2.use Call, IsSuspended do |env2, b3|
              b3.use CreateNetworks if env2[:result]
              b3.use ResumeDomain if env2[:result]
            end

            # only perform shutdown if VM is running
            b2.use Call, IsRunning do |env2, b3|
              next unless env2[:result]

              if env2[:force_halt]
                b3.use HaltDomain
                next
              end

              b3.use StartShutdownTimer
              b3.use Call, GracefulHalt, :shutoff, :running do |env3, b4|
                if !env3[:result]
                  b4.use Call, ShutdownDomain, :shutoff, :running do |env4, b5|
                    if !env4[:result]
                       b5.use HaltDomain
                    end
                  end
                end
              end

            end
          end
        end
      end

      # This is the action implements the reload command
      # It uses the halt and start actions
      def self.action_reload
        Vagrant::Action::Builder.new.tap do |b|
          b.use ConfigValidate
          b.use Call, IsCreated do |env, b2|
            unless env[:result]
              b2.use MessageNotCreated
              next
            end

            b2.use Provision
            b2.use action_halt

            b2.use ResolveDiskSettings
            b2.use action_start
          end
        end
      end

      # not implemented and looks like not require
      def self.action_package
        Vagrant::Action::Builder.new.tap do |b|
          b.use ConfigValidate
          b.use Call, IsCreated do |env, b2|
            unless env[:result]
              b2.use MessageNotCreated
              next
            end

            b2.use PackageSetupFolders
            b2.use PackageSetupFiles
            b2.use action_halt
            b2.use Package
            b2.use PackageDomain
          end
        end
      end

      # This is the action that is primarily responsible for completely
      # freeing the resources of the underlying virtual machine.
      def self.action_destroy
        Vagrant::Action::Builder.new.tap do |b|
          b.use ConfigValidate
          b.use Call, IsCreated do |env, b2|
            unless env[:result]
              # Try to remove stale volumes anyway
              b2.use SetNameOfDomain
              b2.use RemoveStaleVolume if env[:machine].config.vm.box
              b2.use CleanMachineFolder, quiet: true
              b2.use MessageNotCreated unless env[:result]

              next
            end

            b2.use Call, DestroyConfirm do |env2, b3|
              if env2[:result]
                b3.use ProvisionerCleanup, :before
                b3.use ClearForwardedPorts
                b3.use PruneNFSExports
                b3.use DestroyDomain
                b3.use DestroyNetworks
                b3.use CleanMachineFolder
              else
                b3.use MessageWillNotDestroy
              end
            end
          end
        end
      end

      # This action is called to SSH into the machine.
      def self.action_ssh
        Vagrant::Action::Builder.new.tap do |b|
          b.use ConfigValidate
          b.use Call, IsCreated do |env, b2|
            unless env[:result]
              raise Vagrant::Errors::VMNotCreatedError
            end

            b2.use Call, IsRunning do |env2, b3|
              unless env2[:result]
                raise Vagrant::Errors::VMNotRunningError
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
            unless env[:result]
              b2.use MessageNotCreated
              next
            end

            b2.use Call, IsRunning do |env2, b3|
              unless env2[:result]
                b3.use MessageNotRunning
                next
              end

              b3.use Provision
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
            unless env[:result]
              b2.use MessageNotCreated
              next
            end

            b2.use Call, IsRunning do |env2, b3|
              unless env2[:result]
                b3.use MessageNotRunning
                next
              end
              b3.use ClearForwardedPorts
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
            unless env[:result]
              b2.use MessageNotCreated
              next
            end

            b2.use Call, IsSuspended do |env2, b3|
              unless env2[:result]
                b3.use MessageNotSuspended
                next
              end
              b3.use CreateNetworks
              b3.use ResumeDomain
              b3.use Provision
              require 'vagrant/action/builtin/wait_for_communicator'
              b3.use WaitForCommunicator, [:running]
              b3.use ForwardPorts
            end
          end
        end
      end

      def self.action_read_mac_addresses
        Vagrant::Action::Builder.new.tap do |b|
          b.use ConfigValidate
          b.use ReadMacAddresses
        end
      end

      # This is the action that will run a single SSH command.
      def self.action_ssh_run
        Vagrant::Action::Builder.new.tap do |b|
          b.use ConfigValidate
          b.use Call, IsCreated do |env, b2|
            unless env[:result]
              raise Vagrant::Errors::VMNotCreatedError
            end

            b2.use Call, IsRunning do |env2, b3|
              unless env2[:result]
                raise Vagrant::Errors::VMNotRunningError
              end

              b3.use SSHRun
            end
          end
        end
      end

      # This is the action that is primarily responsible for deleting a snapshot
      def self.action_snapshot_delete
        Vagrant::Action::Builder.new.tap do |b|
          b.use ConfigValidate
          b.use Call, IsCreated do |env, b2|
            unless env[:result]
              raise Vagrant::Errors::VMNotCreatedError
            end

            b2.use SnapshotDelete
          end
        end
      end

      # This is the action that is primarily responsible for restoring a snapshot
      def self.action_snapshot_restore
        Vagrant::Action::Builder.new.tap do |b|
          b.use ConfigValidate
          b.use Call, IsCreated do |env, b2|
            unless env[:result]
              raise Vagrant::Errors::VMNotCreatedError
            end

            b2.use SnapshotRestore
          end
        end
      end

      # This is the action that is primarily responsible for saving a snapshot
      def self.action_snapshot_save
        Vagrant::Action::Builder.new.tap do |b|
          b.use ConfigValidate
          b.use Call, IsCreated do |env, b2|
            unless env[:result]
              raise Vagrant::Errors::VMNotCreatedError
            end

            b2.use SnapshotSave
          end
        end
      end

    end
  end
end
