require 'vagrant/action/builder'
require 'log4r'

module VagrantPlugins
  module ProviderLibvirt
    module Action
      autoload :ClearForwardedPorts, File.expand_path("../action/forward_ports", __FILE__)
      autoload :CreateDomain, File.expand_path("../action/create_domain", __FILE__)
      autoload :CreateDomainVolume, File.expand_path("../action/create_domain_volume", __FILE__)
      autoload :CreateNetworkInterfaces, File.expand_path("../action/create_network_interfaces", __FILE__)
      autoload :CreateNetworks, File.expand_path("../action/create_networks", __FILE__)
      autoload :DestroyDomain, File.expand_path("../action/destroy_domain", __FILE__)
      autoload :DestroyNetworks, File.expand_path("../action/destroy_networks", __FILE__)
      autoload :ForwardPorts, File.expand_path("../action/forward_ports", __FILE__)
      autoload :HaltDomain, File.expand_path("../action/halt_domain", __FILE__)
      autoload :HandleBoxImage, File.expand_path("../action/handle_box_image", __FILE__)
      autoload :HandleStoragePool, File.expand_path("../action/handle_storage_pool", __FILE__)
      autoload :IsCreated, File.expand_path("../action/is_created", __FILE__)
      autoload :IsRunning, File.expand_path("../action/is_running", __FILE__)
      autoload :IsSuspended, File.expand_path("../action/is_suspended", __FILE__)
      autoload :MessageAlreadyCreated, File.expand_path("../action/message_already_created", __FILE__)
      autoload :MessageNotCreated, File.expand_path("../action/message_not_created", __FILE__)
      autoload :MessageNotRunning, File.expand_path("../action/message_not_running", __FILE__)
      autoload :MessageNotSuspended, File.expand_path("../action/message_not_suspended", __FILE__)
      autoload :MessageWillNotDestroy, File.expand_path("../action/message_will_not_destroy", __FILE__)
      autoload :PackageDomain, File.expand_path("../action/package_domain", __FILE__)
      autoload :PrepareNFSSettings, File.expand_path("../action/prepare_nfs_settings", __FILE__)
      autoload :PrepareNFSValidIds, File.expand_path("../action/prepare_nfs_valid_ids", __FILE__)
      autoload :PruneNFSExports, File.expand_path("../action/prune_nfs_exports", __FILE__)
      autoload :ReadMacAddresses, File.expand_path("../action/read_mac_addresses", __FILE__)
      autoload :RemoveLibvirtImage, File.expand_path("../action/remove_libvirt_image", __FILE__)
      autoload :RemoveStaleVolume, File.expand_path("../action/remove_stale_volume", __FILE__)
      autoload :ResumeDomain, File.expand_path("../action/resume_domain", __FILE__)
      autoload :SetBootOrder, File.expand_path("../action/set_boot_order", __FILE__)
      autoload :SetNameOfDomain, File.expand_path("../action/set_name_of_domain", __FILE__)

      # @deprecated
      autoload :PrepareNFSValidIds, File.expand_path("../action/prepare_nfs_valid_ids", __FILE__)
      autoload :ShareFolders, File.expand_path("../action/share_folders", __FILE__)
      autoload :StartDomain, File.expand_path("../action/start_domain", __FILE__)
      autoload :SuspendDomain, File.expand_path("../action/suspend_domain", __FILE__)
      autoload :TimedProvision, File.expand_path("../action/timed_provision", __FILE__)
      autoload :WaitTillUp, File.expand_path("../action/wait_till_up", __FILE__)

      # Include the built-in modules so that we can use them as top-level
      # things.
      include Vagrant::Action::Builtin

      # remove image from Libvirt storage pool
      def self.remove_libvirt_image
        Vagrant::Action::Builder.new.tap do |b|
          b.use RemoveLibvirtImage
        end
      end

      # This action brings the machine up from nothing, including importing
      # the box, configuring metadata, and booting.
      def self.action_up
        Vagrant::Action::Builder.new.tap do |b|
          # Handle box_url downloading early so that if the Vagrantfile
          # references any files in the box or something it all just
          # works fine.
          b.use Call, IsCreated do |env, b2|
            if !env[:result]
              b2.use HandleBox
            end
          end

          b.use ConfigValidate
          b.use Call, IsCreated do |env, b2|
            # Create VM if not yet created.
            if !env[:result]
              b2.use SetNameOfDomain
              if !env[:machine].config.vm.box
                b2.use CreateDomain
                b2.use CreateNetworks
                b2.use CreateNetworkInterfaces
                b2.use SetBootOrder
                b2.use StartDomain
              else
                b2.use HandleStoragePool
                b2.use HandleBoxImage
                b2.use CreateDomainVolume
                b2.use CreateDomain

                b2.use Provision
                b2.use PrepareNFSValidIds
                b2.use SyncedFolderCleanup
                b2.use SyncedFolders
                b2.use PrepareNFSSettings
                b2.use ShareFolders
                b2.use CreateNetworks
                b2.use CreateNetworkInterfaces
                b2.use SetBootOrder

                b2.use StartDomain
                b2.use WaitTillUp

                b2.use ForwardPorts
                b2.use SetHostname
                # b2.use SyncFolders
              end
            else
              env[:halt_on_error] = true
              b2.use action_start
            end
          end
        end
      end

      # This action starts a VM, assuming it is already imported and exists.
      # A precondition of this action is that the VM exists.
      def self.action_start
        Vagrant::Action::Builder.new.tap do |b|
          b.use ConfigValidate
          b.use BoxCheckOutdated
          b.use Call, IsRunning do |env, b2|
            # If the VM is running, run the necessary provisioners
            if env[:result]
              b2.use action_provision
              next
            end

            b2.use Call, IsSuspended do |env2, b3|
              # if vm is suspended resume it then exit
              if env2[:result]
                b3.use CreateNetworks
                b3.use ResumeDomain
                next
              end

              if !env[:machine].config.vm.box
                # With no box, we just care about network creation and starting it
                b3.use CreateNetworks
                b3.use SetBootOrder
                b3.use StartDomain
              else
                # VM is not running or suspended.

                b3.use Provision

                # Ensure networks are created and active
                b3.use CreateNetworks
                b3.use SetBootOrder

                b3.use PrepareNFSValidIds
                b3.use SyncedFolderCleanup
                b3.use SyncedFolders

                # Start it..
                b3.use StartDomain

                # Machine should gain IP address when comming up,
                # so wait for dhcp lease and store IP into machines data_dir.
                b3.use WaitTillUp

                b3.use ForwardPorts
                b3.use PrepareNFSSettings
                b3.use ShareFolders
              end
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

            b2.use Call, IsRunning do |env2, b3|
              next unless env2[:result]

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
            unless env[:result]
              b2.use MessageNotCreated
              next
            end

            b2.use ConfigValidate
            b2.use action_halt
            b2.use action_start
          end
        end
      end

      # This action packages the virtual machine into a single box file.
      def self.action_package
        Vagrant::Action::Builder.new.tap do |b|
          b.use Call, IsCreated do |env1, b2|
            if !env1[:result]
              b2.use MessageNotCreated
              next
            end

            b2.use ConfigValidate
            b2.use action_halt
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
              b2.use MessageNotCreated
              next
            end

            b2.use Call, IsRunning do |env2, b3|
              unless env2[:result]
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
              # b3.use SyncFolders
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
              b2.use MessageNotCreated
              next
            end

            b2.use Call, IsRunning do |env2, b3|
              unless env2[:result]
                b3.use MessageNotRunning
                next
              end

              b3.use SSHRun
            end
          end
        end
      end
    end
  end
end
