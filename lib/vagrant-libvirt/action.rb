require 'vagrant/action/builder'

module VagrantPlugins
  module Libvirt
    module Action
      # Include the built-in modules so we can use them as top-level things.
      include Vagrant::Action::Builtin

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
              b2.use HandleBoxImage
              b2.use CreateDomainVolume
              b2.use CreateDomain
              b2.use CreateNetworkInterfaces

              b2.use TimedProvision
              b2.use StartDomain
              b2.use WaitTillUp
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
              if env2[:result]
                b3.use ResumeDomain
                next
              end

              # VM is not running or suspended. Start it.. Machine should gain
              # IP address when comming up, so wait for dhcp lease and store IP
              # into machines data_dir.
              b3.use StartDomain
              b3.use WaitTillUp
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

              # VM is running, halt it.. Cleanup running instance data. Now
              # only IP address is stored.
              b3.use HaltDomain
              b3.use CleanupDataDir
            end
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
            b2.use DestroyDomain

            # Cleanup running instance data. Now only IP address is stored.
            b2.use CleanupDataDir
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

      action_root = Pathname.new(File.expand_path("../action", __FILE__))
      autoload :ConnectLibvirt, action_root.join("connect_libvirt")
      autoload :IsCreated, action_root.join("is_created")
      autoload :IsRunning, action_root.join("is_running")
      autoload :IsSuspended, action_root.join("is_suspended")
      autoload :MessageAlreadyCreated, action_root.join("message_already_created")
      autoload :MessageNotCreated, action_root.join("message_not_created")
      autoload :MessageNotRunning, action_root.join("message_not_running")
      autoload :MessageNotSuspended, action_root.join("message_not_suspended")
      autoload :HandleStoragePool, action_root.join("handle_storage_pool")
      autoload :HandleBoxImage, action_root.join("handle_box_image")
      autoload :SetNameOfDomain, action_root.join("set_name_of_domain")
      autoload :CreateDomainVolume, action_root.join("create_domain_volume")
      autoload :CreateDomain, action_root.join("create_domain")
      autoload :CreateNetworkInterfaces, action_root.join("create_network_interfaces")
      autoload :DestroyDomain, action_root.join("destroy_domain")
      autoload :StartDomain, action_root.join("start_domain")
      autoload :HaltDomain, action_root.join("halt_domain")
      autoload :SuspendDomain, action_root.join("suspend_domain")
      autoload :ResumeDomain, action_root.join("resume_domain")
      autoload :CleanupDataDir, action_root.join("cleanup_data_dir")
      autoload :ReadState, action_root.join("read_state")
      autoload :ReadSSHInfo, action_root.join("read_ssh_info")
      autoload :TimedProvision, action_root.join("timed_provision")
      autoload :WaitTillUp, action_root.join("wait_till_up")
      autoload :SyncFolders, action_root.join("sync_folders")
    end
  end
end

