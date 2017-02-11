require 'log4r'
require 'ostruct'
require 'nokogiri'
require 'digest/md5'

require 'vagrant/util/subprocess'
require 'vagrant/errors'
require 'vagrant-libvirt/errors'
# require_relative "helper"

module VagrantPlugins
  module SyncedFolder9p
    class SyncedFolder < Vagrant.plugin('2', :synced_folder)
      include Vagrant::Util
      include VagrantPlugins::ProviderLibvirt::Util::ErbTemplate

      def initialize(*args)
        super
        @logger = Log4r::Logger.new('vagrant_libvirt::synced_folders::9p')
      end

      def usable?(machine, _raise_error = false)
        # bail now if not using libvirt since checking version would throw error
        return false unless machine.provider_name == :libvirt

        # <filesystem/> support in device attach/detach introduced in 1.2.2
        # version number format is major * 1,000,000 + minor * 1,000 + release
        libvirt_version = machine.provider.driver.connection.client.libversion
        libvirt_version >= 1_002_002
      end

      def prepare(machine, folders, _opts)
        raise Vagrant::Errors::Error('No libvirt connection') if machine.provider.driver.connection.nil?
        @conn = machine.provider.driver.connection.client

        begin
          # loop through folders
          folders.each do |id, folder_opts|
            folder_opts.merge!(target: id,
                               accessmode: 'passthrough',
                               mount: true,
                               readonly: nil) { |_k, ov, _nv| ov }

            mount_tag = Digest::MD5.new.update(folder_opts[:hostpath]).to_s[0, 31]
            folder_opts[:mount_tag] = mount_tag

            machine.ui.info "================\nMachine id: #{machine.id}\nShould be mounting folders\n #{id}, opts: #{folder_opts}"

            #xml = to_xml('filesystem', folder_opts)
            xml = Nokogiri::XML::Builder.new do |xml|
              xml.filesystem(type: 'mount', accessmode: folder_opts[:accessmode]) do
                xml.driver(type: 'path', wrpolicy: 'immediate')
                xml.source(dir: folder_opts[:hostpath])
                xml.target(dir: mount_tag)
                xml.readonly unless folder_opts[:readonly].nil?
              end
            end.to_xml(
              save_with: Nokogiri::XML::Node::SaveOptions::NO_DECLARATION |
                         Nokogiri::XML::Node::SaveOptions::NO_EMPTY_TAGS |
                         Nokogiri::XML::Node::SaveOptions::FORMAT
            )
            # puts "<<<<< XML:\n #{xml}\n >>>>>"
            @conn.lookup_domain_by_uuid(machine.id).attach_device(xml, 0)
          end
        rescue => e
          machine.ui.error("could not attach device because: #{e}")
          raise VagrantPlugins::ProviderLibvirt::Errors::AttachDeviceError,
                error_message: e.message
        end
      end

      # TODO: once up, mount folders
      def enable(machine, folders, _opts)
        # Go through each folder and mount
        machine.ui.info('mounting p9 share in guest')
        # Only mount folders that have a guest path specified.
        mount_folders = {}
        folders.each do |id, opts|
          next unless opts[:mount] && opts[:guestpath] && !opts[:guestpath].empty?
          mount_folders[id] = opts.dup
          # merge common options if not given
          mount_folders[id].merge!(version: '9p2000.L') { |_k, ov, _nv| ov }
        end
        # Mount the actual folder
        machine.guest.capability(
          :mount_p9_shared_folder, mount_folders
        )
      end

      def cleanup(machine, _opts)
        if machine.provider.driver.connection.nil?
          raise Vagrant::Errors::Error('No libvirt connection')
        end
        @conn = machine.provider.driver.connection.client
        begin
          if machine.id && machine.id != ''
            dom = @conn.lookup_domain_by_uuid(machine.id)
            Nokogiri::XML(dom.xml_desc).xpath(
              '/domain/devices/filesystem'
            ).each do |xml|
              dom.detach_device(xml.to_s)
              machine.ui.info 'Cleaned up shared folders'
            end
          end
        rescue => e
          machine.ui.error("could not detach device because: #{e}")
          raise VagrantPlugins::ProviderLibvirt::Errors::DetachDeviceError,
                error_message: e.message
        end
      end
    end
  end
end
