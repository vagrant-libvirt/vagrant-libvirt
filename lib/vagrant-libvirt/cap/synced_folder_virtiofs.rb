# frozen_string_literal: true

require 'log4r'
require 'ostruct'
require 'nokogiri'
require 'digest/md5'

require 'vagrant/errors'
require 'vagrant/util/subprocess'

require 'vagrant-libvirt/errors'
require 'vagrant-libvirt/util/erb_template'

module VagrantPlugins
  module SyncedFolderVirtioFS
    class SyncedFolder < Vagrant.plugin('2', :synced_folder)
      include Vagrant::Util
      include VagrantPlugins::ProviderLibvirt::Util::ErbTemplate

      def initialize(*args)
        super
        @logger = Log4r::Logger.new('vagrant_libvirt::synced_folders::virtiofs')
      end

      def usable?(machine, _raise_error = false)
        # bail now if not using Libvirt since checking version would throw error
        return false unless machine.provider_name == :libvirt

        # virtiofs support introduced since 6.2.0
        # version number format is major * 1,000,000 + minor * 1,000 + release
        libvirt_version = machine.provider.driver.connection.client.libversion
        libvirt_version >= 6_002_000
      end

      def prepare(machine, folders, _opts)
        raise Vagrant::Errors::Error('No Libvirt connection') if machine.provider.driver.connection.nil?
        @conn = machine.provider.driver.connection.client

        machine.ui.info I18n.t("vagrant_libvirt.cap.virtiofs.preparing")

        begin
          # loop through folders
          folders.each do |id, folder_opts|
            folder_opts.merge!(target: id,
                               mount: true,
                               readonly: nil) { |_k, ov, _nv| ov }

            mount_tag = Digest::MD5.new.update(folder_opts[:hostpath]).to_s[0, 31]
            folder_opts[:mount_tag] = mount_tag

            xml = Nokogiri::XML::Builder.new do |xml|
              xml.filesystem(type: 'mount', accessmode: 'passthrough') do
                xml.driver(type: 'virtiofs')
                xml.source(dir: folder_opts[:hostpath])
                xml.target(dir: mount_tag)
                xml.readonly unless folder_opts[:readonly].nil?
              end
            end.to_xml(
              save_with: Nokogiri::XML::Node::SaveOptions::NO_DECLARATION |
                         Nokogiri::XML::Node::SaveOptions::NO_EMPTY_TAGS |
                         Nokogiri::XML::Node::SaveOptions::FORMAT
            )
            @logger.debug {
              "Attaching Synced Folder device with XML:\n#{xml}"
            }
            @conn.lookup_domain_by_uuid(machine.id).attach_device(xml, 0)
          end
        rescue => e
          machine.ui.error("could not attach device because: #{e}")
          raise VagrantPlugins::ProviderLibvirt::Errors::AttachDeviceError,
                error_message: e.message
        end
      end

      # once up, mount folders
      def enable(machine, folders, _opts)
        # Go through each folder and mount
        machine.ui.info I18n.t("vagrant_libvirt.cap.virtiofs.mounting")
        # Only mount folders that have a guest path specified.
        mount_folders = {}
        folders.each do |id, opts|
          next unless opts[:mount] && opts[:guestpath] && !opts[:guestpath].empty?
          mount_folders[id] = opts.dup
        end
        # Mount the actual folder
        machine.guest.capability(
          :mount_virtiofs_shared_folder, mount_folders
        )
      end

      def cleanup(machine, _opts)
        if machine.provider.driver.connection.nil?
          raise Vagrant::Errors::Error('No Libvirt connection')
        end
        @conn = machine.provider.driver.connection.client
        machine.ui.info I18n.t("vagrant_libvirt.cap.virtiofs.cleanup")
        begin
          if machine.id && machine.id != ''
            dom = @conn.lookup_domain_by_uuid(machine.id)
            Nokogiri::XML(dom.xml_desc).xpath(
              '/domain/devices/filesystem'
            ).each do |xml|
              dom.detach_device(xml.to_s)
            end
          end
        rescue => e
          machine.ui.error("could not detach device because: #{e}")
          raise VagrantPlugins::ProviderLibvirt::Errors::DetachDeviceError,
                error_message: e.message
        end
      end

      # Enable virtiofs synced folders within WSL when in use
      # on non-DrvFs file systems
      def self.wsl_allow_non_drvfs?
        true
      end
    end
  end
end
