# frozen_string_literal: true

require 'log4r'
require 'open3'
require 'json'

require 'vagrant-libvirt/util/byte_number'
require 'vagrant-libvirt/util/storage_util'

module VagrantPlugins
  module ProviderLibvirt
    module Action
      class HandleBoxImage
        include VagrantPlugins::ProviderLibvirt::Util::StorageUtil

        @@lock = Mutex.new

        def initialize(app, _env)
          @logger = Log4r::Logger.new('vagrant_libvirt::action::handle_box_image')
          @app = app
        end

        def call(env)
          # Handle box formats converting between v1 => v2 and ensuring
          # any obsolete settings are rejected.

          disks = env[:machine].box.metadata.fetch('disks', [])
          if disks.empty?
            # Handle box v1 format

            # Only qcow2 format is supported in v1, but other formats with backing
            # store capability should be usable.
            box_format = env[:machine].box.metadata['format']
            HandleBoxImage.verify_box_format(box_format)

            image_path = HandleBoxImage.get_box_image_path(env[:machine].box, 'box.img')
            env[:box_volume_number] = 1
            env[:box_volumes] = [{
              :path => image_path,
              :name => HandleBoxImage.get_volume_name(env[:machine].box, 'box', image_path, env[:ui]),
              :virtual_size => HandleBoxImage.get_virtual_size(env),
              :format => box_format,
              :compat => "1.1",
            }]
          else
            # Handle box v2 format
            # {
            #   'path': '<path-of-file-box>',
            #   'name': '<name-to-use-in-storage>' # optional, will use index
            # }
            #
            env[:box_volume_number] = disks.length()
            target_volumes = Hash[]
            env[:box_volumes] = Array.new(env[:box_volume_number]) { |i|
              raise Errors::BoxFormatMissingAttribute, attribute: "disks[#{i}]['path']" if disks[i]['path'].nil?

              image_path = HandleBoxImage.get_box_image_path(env[:machine].box, disks[i]['path'])
              format, virtual_size, compat = HandleBoxImage.get_box_disk_settings(image_path)
              volume_name = HandleBoxImage.get_volume_name(
                env[:machine].box,
                disks[i].fetch('name', disks[i]['path'].sub(/#{File.extname(disks[i]['path'])}$/, '')),
                image_path,
                env[:ui],
              )

              # allowing name means needing to check that it doesn't cause a clash
              existing = target_volumes[volume_name]
              if !existing.nil?
                raise Errors::BoxFormatDuplicateVolume, volume: volume_name, new_disk: "disks[#{i}]", orig_disk: "disks[#{existing}]"
              end
              target_volumes[volume_name] = i

              {
                :path => image_path,
                :name => volume_name,
                :virtual_size => virtual_size,
                :format => HandleBoxImage.verify_box_format(format),
                :compat => compat,
              }
            }
          end

          # Get config options
          config = env[:machine].provider_config
          box_image_files = []
          env[:box_volumes].each do |d|
            box_image_files.push(d[:path])
          end

          # Override box_virtual_size
          box_virtual_size = env[:box_volumes][0][:virtual_size]
          if config.machine_virtual_size
            config_machine_virtual_size = ByteNumber.from_GB(config.machine_virtual_size)
            if config_machine_virtual_size < box_virtual_size
              # Warn that a virtual size less than the box metadata size
              # is not supported and will be ignored
              env[:ui].warn I18n.t(
                'vagrant_libvirt.warnings.ignoring_virtual_size_too_small',
                  requested: config_machine_virtual_size.to_GB, minimum: box_virtual_size.to_GB
              )
            else
              env[:ui].info I18n.t('vagrant_libvirt.manual_resize_required')
              box_virtual_size = config_machine_virtual_size
            end
          end
          # save for use by later actions
          env[:box_volumes][0][:virtual_size] = box_virtual_size
          # special handling for domain volume
          env[:box_volumes][0][:device] ||= config.disk_device

          # while inside the synchronize block take care not to call the next
          # action in the chain, as must exit this block first to prevent
          # locking all subsequent actions as well.
          @@lock.synchronize do
            env[:box_volumes].each_index do |i|
              box_volume = env[:box_volumes][i]
              # Don't continue if image already exists in storage pool.
              fog_volume = env[:machine].provider.driver.connection.volumes.all(
                name: box_volume[:name]
              ).first
              next if fog_volume && fog_volume.id
              @logger.info("Creating volume #{box_volume[:name]} in storage pool #{config.storage_pool_name}.")
              storage_send_box_image(env, config, box_image_files[i], box_volume)
            end
          end

          # Continue the middleware chain.
          @app.call(env)
        end

        protected

        def self.get_volume_name(box, name, path, ui)
          version = begin
                      box.version.to_s
                    rescue
                      ''
                    end

          if version.empty? || version == '0'
            ui.warn(I18n.t('vagrant_libvirt.box_version_missing', name: box.name.to_s))

            version = "0_#{File.mtime(path).to_i}"
          end

          vol_name = box.name.to_s.dup.gsub('/', '-VAGRANTSLASH-')
          vol_name << "_vagrant_box_image_#{version}_#{name.dup.gsub('/', '-SLASH-')}.img"
        end

        def self.get_virtual_size(env)
          # Virtual size has to be set for allocating space in storage pool.
          box_virtual_size = env[:machine].box.metadata['virtual_size']
          raise Errors::NoBoxVirtualSizeSet if box_virtual_size.nil?
          return ByteNumber.from_GB(box_virtual_size)
        end

        def self.get_box_image_path(box, box_name)
          return box.directory.join(box_name).to_s
        end

        def self.verify_box_format(box_format, disk_index=nil)
          if box_format.nil?
            raise Errors::NoBoxFormatSet
          elsif box_format != 'qcow2'
            if disk_index.nil?
              raise Errors::WrongBoxFormatSet
            else
              raise Errors::WrongDiskFormatSet,
                disk_index: disk_index
            end
          end
          return box_format
        end

        def self.get_box_disk_settings(image_path)
          stdout, stderr, status = Open3.capture3('qemu-img', 'info', '--output=json', image_path)
          if !status.success?
            raise Errors::BadBoxImage, image: image_path, out: stdout, err: stderr
          end

          image_info = JSON.parse(stdout)
          format = image_info['format']
          virtual_size = ByteNumber.new(image_info['virtual-size'])
          compat = image_info.fetch("format-specific", {}).fetch("data", {}).fetch("compat", "0.10")

          return format, virtual_size, compat
        end

      end
    end
  end
end
