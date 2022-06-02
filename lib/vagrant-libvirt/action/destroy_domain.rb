# frozen_string_literal: true

require 'log4r'

begin
  require 'rexml'
rescue LoadError
  require 'rexml/rexml'
end

module VagrantPlugins
  module ProviderLibvirt
    module Action
      class DestroyDomain
        def initialize(app, _env)
          @logger = Log4r::Logger.new('vagrant_libvirt::action::destroy_domain')
          @app = app
        end

        def call(env)
          # Destroy the server, remove the tracking ID
          env[:ui].info(I18n.t('vagrant_libvirt.destroy_domain'))

          # Must delete any snapshots before domain can be destroyed
          # Fog Libvirt currently doesn't support snapshots. Use
          # ruby-libvirt client directly. Note this is racy, see
          # http://www.libvirt.org/html/libvirt-libvirt.html#virDomainSnapshotListNames
          libvirt_domain = env[:machine].provider.driver.connection.client.lookup_domain_by_uuid(
            env[:machine].id
          )
          begin
            libvirt_domain.list_snapshots.each do |name|
              @logger.info("Deleting snapshot '#{name}'")
              begin
                libvirt_domain.lookup_snapshot_by_name(name).delete
              rescue => e
                raise Errors::SnapshotDeletionError, error_message: e.message
              end
            end
          rescue
            # Some drivers (xen) don't support getting list of snapshots,
            # not much can be done here about it
            @logger.warn("Failed to get list of snapshots")
          end

          # must remove managed saves
          libvirt_domain.managed_save_remove if libvirt_domain.has_managed_save?

          domain = env[:machine].provider.driver.connection.servers.get(env[:machine].id.to_s)

          undefine_flags = 0
          undefine_flags |= ProviderLibvirt::Util::DomainFlags::VIR_DOMAIN_UNDEFINE_KEEP_NVRAM if env[:machine].provider_config.nvram

          if env[:machine].provider_config.disks.empty? &&
             env[:machine].provider_config.cdroms.empty?
            # if using default configuration of disks and cdroms
            # cdroms are consider volumes, but cannot be destroyed
            destroy_domain(domain, destroy_volumes: true, flags: undefine_flags)
          else
            domain_xml = libvirt_domain.xml_desc(1)
            xml_descr = REXML::Document.new(domain_xml)
            disks_xml = REXML::XPath.match(xml_descr, '/domain/devices/disk[@device="disk"]')
            have_aliases = !(REXML::XPath.match(disks_xml, './alias[@name="ua-box-volume-0"]').first).nil?
            if !have_aliases
              env[:ui].warn(I18n.t('vagrant_libvirt.domain_xml.obsolete_method'))
            end

            destroy_domain(domain, destroy_volumes: false, flags: undefine_flags)

            volumes = domain.volumes

            # Remove root storage. If no aliases available, perform the removal by name and keep track
            # of how many matches there are in the volumes. This will provide a fallback offset to where
            # the additional storage devices are.
            detected_box_volumes = 0
            if have_aliases
              REXML::XPath.match(disks_xml, './alias[contains(@name, "ua-box-volume-")]').each do |box_disk|
                diskname = box_disk.parent.elements['source'].attributes['file'].rpartition('/').last
                detected_box_volumes += 1

                destroy_volume(volumes, diskname, env)
              end
            else
              # fallback to try and infer which boxes are box images, as they are listed first
              # as soon as there is no match, can exit
              disks_xml.each_with_index do |box_disk, idx|
                name = libvirt_domain.name + (idx == 0 ? '.img' : "_#{idx}.img")
                diskname = box_disk.elements['source'].attributes['file'].rpartition('/').last

                break if name != diskname
                detected_box_volumes += 1

                root_disk = volumes.select do |x|
                  x.name == name if x
                end.first
                if root_disk
                  root_disk.destroy
                end
              end
            end

            # work out if there are any custom disks attached that wasn't done by vagrant-libvirt,
            # and warn there might be unexpected behaviour
            total_disks = disks_xml.length
            offset = total_disks - env[:machine].provider_config.disks.length
            if offset != detected_box_volumes
              env[:ui].warn(I18n.t('vagrant_libvirt.destroy.unexpected_volumes'))
            end

            if !have_aliases
              # if no aliases found, see if it's possible to check the number of box disks
              # otherwise the destroy could remove the wrong disk by accident.
              if env[:machine].box != nil
                box_disks = env[:machine].box.metadata.fetch('disks', [1])
                offset = box_disks.length
                if offset != detected_box_volumes
                  env[:ui].warn(I18n.t('vagrant_libvirt.destroy.expected_removal_mismatch'))
                end
              else
                env[:ui].warn(I18n.t('vagrant_libvirt.destroy.box_metadata_unavailable'))
              end

              # offset only used when no aliases available
              offset = detected_box_volumes
            end

            env[:machine].provider_config.disks.each_with_index.each do |disk, index|
              # shared disks remove only manually or ???
              next if disk[:allow_existing]

              # look for exact match using aliases which will be used
              # for subsequent domain creations
              if have_aliases
                domain_disk = REXML::XPath.match(disks_xml, './alias[@name="ua-disk-volume-' + index.to_s + '"]').first
                domain_disk = domain_disk.parent if !domain_disk.nil?
              else
                # otherwise fallback to find the disk by device if specified by user
                # and finally index counting with offset and hope the match is correct
                if !disk[:device].nil?
                  domain_disk = REXML::XPath.match(disks_xml, './target[@dev="' + disk[:device] + '"]').first
                  domain_disk = domain_disk.parent if !domain_disk.nil?
                else
                  domain_disk = disks_xml[offset + index]
                end
              end

              next if domain_disk.nil?

              diskname = domain_disk.elements['source'].attributes['file'].rpartition('/').last
              destroy_volume(volumes, diskname, env)
            end
          end

          @app.call(env)
        end

        protected

        def destroy_volume(volumes, diskname, env)
          # diskname is unique
          libvirt_disk = volumes.select do |x|
            x.name == diskname if x
          end.first
          if libvirt_disk
            libvirt_disk.destroy
          elsif disk[:path]
            poolname = env[:machine].provider_config.storage_pool_name
            libvirt_disk = volumes.select do |x|
              # FIXME: can remove pool/target.img and pool/123/target.img
              x.path =~ /\/#{disk[:path]}$/ && x.pool_name == poolname
            end.first
            libvirt_disk.destroy if libvirt_disk
          end
        end

        def destroy_domain(domain, destroy_volumes:, flags:)
          if domain.method(:destroy).parameters.first.include?(:flags)
            domain.destroy(destroy_volumes: destroy_volumes, flags: flags)
          else
            domain.destroy(destroy_volumes: destroy_volumes)
          end
        end
      end
    end
  end
end
