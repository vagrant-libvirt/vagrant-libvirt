# frozen_string_literal: true

require 'log4r'

require 'rexml/document'
require 'rexml/xpath'

require 'vagrant-libvirt/util/resolvers'

module VagrantPlugins
  module ProviderLibvirt
    module Action
      class ResolveDiskSettings
        def initialize(app, _env)
          @logger = Log4r::Logger.new('vagrant_libvirt::action::resolve_disk_devices')
          @app = app
        end

        def call(env)
          # Get config.
          config = env[:machine].provider_config

          domain_name = env[:domain_name] # only set on create
          disk_bus = config.disk_bus
          disk_device = config.disk_device
          domain_volume_cache = config.volume_cache || 'default'

          # Storage
          storage_pool_name = config.storage_pool_name
          snapshot_pool_name = config.snapshot_pool_name
          domain_volumes = []
          disks = config.disks.dup

          resolver = ::VagrantPlugins::ProviderLibvirt::Util::DiskDeviceResolver.new(disk_device[0..1])

          # Get path to domain image from the storage pool selected if we have a box.
          if env[:machine].config.vm.box
            pool_name = if snapshot_pool_name == storage_pool_name
                          storage_pool_name
                        else
                          snapshot_pool_name
                        end

            if env[:box_volumes].nil?
              # domain must be already created, need to read domain volumes from domain XML
              libvirt_domain = env[:machine].provider.driver.connection.client.lookup_domain_by_uuid(
                env[:machine].id
              )
              domain_xml = libvirt_domain.xml_desc(1)
              xml_descr = REXML::Document.new(domain_xml)
              domain_name = xml_descr.elements['domain'].elements['name'].text
              disks_xml = REXML::XPath.match(xml_descr, '/domain/devices/disk[@device="disk"]')
              have_aliases = !REXML::XPath.match(disks_xml, './alias[@name="ua-box-volume-0"]').first.nil?
              env[:ui].warn(I18n.t('vagrant_libvirt.domain_xml.obsolete_method')) unless have_aliases

              if have_aliases
                REXML::XPath.match(disks_xml,
                                   './alias[contains(@name, "ua-box-volume-")]').each_with_index do |alias_xml, idx|
                  domain_volumes.push(volume_from_xml(alias_xml.parent, domain_name, idx))
                end
              else
                # fallback to try and infer which boxes are box images, as they are listed first
                # as soon as there is no match, can exit
                disks_xml.each_with_index do |box_disk_xml, idx|
                  diskname = box_disk_xml.elements['source'].attributes['file'].rpartition('/').last

                  break if volume_name(domain_name, idx) != diskname

                  domain_volumes.push(volume_from_xml(box_disk_xml, domain_name, idx))
                end
              end
            else

              @logger.debug "Search for volumes in pool: #{pool_name}"
              env[:box_volumes].each_index do |index|
                domain_volume = env[:machine].provider.driver.connection.volumes.all(
                  name: volume_name(domain_name, index)
                ).find { |x| x.pool_name == pool_name }
                raise Errors::NoDomainVolume if domain_volume.nil?

                domain_volumes.push(
                  {
                    name: volume_name(domain_name, index),
                    device: env[:box_volumes][index][:device],
                    cache: domain_volume_cache,
                    bus: disk_bus,
                    absolute_path: domain_volume.path,
                    virtual_size: env[:box_volumes][index][:virtual_size],
                    pool: pool_name,
                  }
                )
              end
            end

            resolver.resolve!(domain_volumes)

            # If we have a box, take the path from the domain volume and set our storage_prefix.
            # If not, we dump the storage pool xml to get its defined path.
            # the default storage prefix is typically: /var/lib/libvirt/images/
            storage_prefix = "#{File.dirname(domain_volumes[0][:absolute_path])}/" # steal
          else
            if domain_name.nil?
              # Ensure domain name is set for subsequent steps if restarting a machine without a box
              libvirt_domain = env[:machine].provider.driver.connection.client.lookup_domain_by_uuid(
                env[:machine].id
              )
              domain_xml = libvirt_domain.xml_desc(1)
              xml_descr = REXML::Document.new(domain_xml)
              domain_name = xml_descr.elements['domain'].elements['name'].text
            end

            storage_prefix = get_disk_storage_prefix(env[:machine], storage_pool_name)
          end

          resolver.resolve!(disks)

          disks.each do |disk|
            disk[:path] ||= disk_name(domain_name, disk)

            # On volume creation, the <path> element inside <target>
            # is oddly ignored; instead the path is taken from the
            # <name> element:
            # http://www.redhat.com/archives/libvir-list/2008-August/msg00329.html
            disk[:name] = disk[:path]

            disk[:absolute_path] = storage_prefix + disk[:path]

            if disk[:pool].nil?
              disk[:pool] = storage_pool_name
            else
              @logger.debug "Overriding pool name with: #{disk[:pool]}"
              disk_storage_prefix = get_disk_storage_prefix(env[:machine], disk[:pool])
              disk[:absolute_path] = disk_storage_prefix + disk[:path]
              @logger.debug "Overriding disk path with: #{disk[:absolute_path]}"
            end
          end

          env[:domain_volumes] = domain_volumes
          env[:disks] = disks

          @app.call(env)
        end

        private

        def disk_name(name, disk)
          "#{name}-#{disk[:device]}.#{disk[:type]}" # disk name
        end

        def get_disk_storage_prefix(machine, disk_pool_name)
          disk_storage_pool = machine.provider.driver.connection.client.lookup_storage_pool_by_name(disk_pool_name)
          raise Errors::NoStoragePool if disk_storage_pool.nil?

          xml = Nokogiri::XML(disk_storage_pool.xml_desc)
          "#{xml.xpath('/pool/target/path').inner_text}/"
        end

        def volume_name(domain_name, index)
          domain_name + (index.zero? ? '.img' : "_#{index}.img")
        end

        def volume_from_xml(device_xml, domain_name, index)
          driver = device_xml.elements['driver']
          source = device_xml.elements['source']
          target = device_xml.elements['target']

          {
            name: volume_name(domain_name, index),
            device: target.attributes['dev'],
            cache: driver.attributes['cache'],
            bus: target.attributes['bus'],
            absolute_path: source.attributes['file'],
          }
        end
      end
    end
  end
end
