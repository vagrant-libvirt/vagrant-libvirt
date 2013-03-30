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
            if env[:result]
              b2.use Call, ReadState do |env2,b3|
                if env2[:machine_state_id] == 'paused'
                  b3.use StartDomain
                  return true
                end
              end
              b2.use MessageAlreadyCreated
              next
            end

            b2.use SetNameOfDomain
            b2.use HandleStoragePool
            b2.use HandleBoxImage
            b2.use CreateDomainVolume
            b2.use CreateDomain
            b2.use CreateNetworkInterfaces
          end

          b.use TimedProvision
          b.use StartDomain
          b.use WaitTillUp
          b.use SyncFolders
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

      # suspend
      # save vm to file
      def self.action_suspend
        Vagrant::Action::Builder.new.tap do |b|
          b.use ConfigValidate
          b.use ConnectLibvirt
          b.use Suspend
        end
      end

      action_root = Pathname.new(File.expand_path("../action", __FILE__))
      autoload :Suspend, action_root.join("suspend")
      autoload :ConnectLibvirt, action_root.join("connect_libvirt")
      autoload :IsCreated, action_root.join("is_created")
      autoload :MessageAlreadyCreated, action_root.join("message_already_created")
      autoload :MessageNotCreated, action_root.join("message_not_created")
      autoload :HandleStoragePool, action_root.join("handle_storage_pool")
      autoload :HandleBoxImage, action_root.join("handle_box_image")
      autoload :SetNameOfDomain, action_root.join("set_name_of_domain")
      autoload :CreateDomainVolume, action_root.join("create_domain_volume")
      autoload :CreateDomain, action_root.join("create_domain")
      autoload :CreateNetworkInterfaces, action_root.join("create_network_interfaces")
      autoload :DestroyDomain, action_root.join("destroy_domain")
      autoload :StartDomain, action_root.join("start_domain")
      autoload :ReadState, action_root.join("read_state")
      autoload :ReadSSHInfo, action_root.join("read_ssh_info")
      autoload :TimedProvision, action_root.join("timed_provision")
      autoload :WaitTillUp, action_root.join("wait_till_up")
      autoload :SyncFolders, action_root.join("sync_folders")
    end
  end
end

