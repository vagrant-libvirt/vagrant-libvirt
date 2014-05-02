require "log4r"
require 'ostruct'
require 'nokogiri'


require "vagrant/util/subprocess"
require "vagrant/errors"
require "vagrant-libvirt/errors"
# require_relative "helper"

module VagrantPlugins
  module SyncedFolder9p
    class SyncedFolder < Vagrant.plugin("2", :synced_folder)
      include Vagrant::Util
      include VagrantPlugins::ProviderLibvirt::Util::ErbTemplate

      def initialize(*args)
        super

        @logger = Log4r::Logger.new("vagrant_libvirt::synced_folders::9p")
      end

      def usable?(machine, raise_error=false)
        # TODO check for host support (eg in linux is 9p compiled ?)
        # and support in Qemu for instance ?
        machine.provider_name == :libvirt
      end

      def prepare(machine, folders, opts)
        
        raise Vagrant::Errors::Error("No libvirt connection") if ProviderLibvirt.libvirt_connection.nil?
      
        @conn = ProviderLibvirt.libvirt_connection.client

        begin
          # loop through folders
          folders.each do |id, folder_opts|
            folder_opts.merge!({ :accessmode => "passthrough",
                                :readonly => nil })
            machine.ui.info "================\nMachine id: #{machine.id}\nShould be mounting folders\n #{id}, opts: #{folder_opts}"

            xml =  to_xml('filesystem', folder_opts )
            # puts "<<<<< XML:\n #{xml}\n >>>>>"
            @conn.lookup_domain_by_uuid(machine.id).attach_device(xml, 0)

          end 
        rescue => e
          machine.ui.error("could not attach device because: #{e}")
          raise VagrantPlugins::ProviderLibvirt::Errors::AttachDeviceError,:error_message => e.message
        end
      end


      # TODO once up, mount folders
      def enable(machine, folders, _opts)
        # Go through each folder and mount
        machine.ui.info("mounting p9 share in guest")
        # Only mount folders that have a guest path specified.
        mount_folders = {}
        folders.each do |id, opts|
          mount_folders[id] = opts.dup if opts[:guestpath]
        end
        common_opts = {
          :version => '9p2000.L',
        }
        # Mount the actual folder
        machine.guest.capability(
            :mount_p9_shared_folder, mount_folders, common_opts)
      end

      def cleanup(machine, _opts)

        raise Vagrant::Errors::Error("No libvirt connection") if ProviderLibvirt.libvirt_connection.nil?

        @conn = ProviderLibvirt.libvirt_connection.client
 
        begin
          if machine.id && machine.id != ""
            dom = @conn.lookup_domain_by_uuid(machine.id)
            Nokogiri::XML(dom.xml_desc).xpath('/domain/devices/filesystem').each do |xml|
              dom.detach_device(xml.to_s)

              machine.ui.info "Cleaned up shared folders"
            end
          end
        rescue => e
          machine.ui.error("could not detach device because: #{e}")
          raise VagrantPlugins::ProviderLibvirt::Errors::DetachDeviceError,:error_message => e.message
        end

      end

    end
  end
end
