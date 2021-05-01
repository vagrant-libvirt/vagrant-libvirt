require 'log4r'

module VagrantPlugins
  module ProviderLibvirt
    module Action
      class HandleBoxImage
        include VagrantPlugins::ProviderLibvirt::Util::StorageUtil
        include VagrantPlugins::ProviderLibvirt::Util::Ui


        @@lock = Mutex.new

        def initialize(app, _env)
          @logger = Log4r::Logger.new('vagrant_libvirt::action::handle_box_image')
          @app = app
        end

        def self.get_volume_name(env, index)
          name = env[:machine].box.name.to_s.dup.gsub('/', '-VAGRANTSLASH-')
          name << "_vagrant_box_image_#{
          begin
            env[:machine].box.version.to_s
          rescue
            ''
          end}_#{index}.img"
          return name
        end

        def self.get_virtual_size(env)
          # Virtual size has to be set for allocating space in storage pool.
          box_virtual_size = env[:machine].box.metadata['virtual_size']
          raise Errors::NoBoxVirtualSizeSet if box_virtual_size.nil?
          return box_virtual_size
        end

        def self.get_default_box_image_path(index)
          return index <= 0 ? 'box.img' : "box_#{index}.img"
        end

        def self.get_box_image_path(env, box_name)
          return env[:machine].box.directory.join(box_name).to_s
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

        def self.verify_virtual_size_in_disks(disks)
          disks.each_with_index do |disk, index|
            raise Errors::NoDiskVirtualSizeSet, disk_index:index if disk['virtual_size'].nil?
          end
        end

        def send_box_image(env, config, box_image_file, box_volume)
          # Box is not available as a storage pool volume. Create and upload
          # it as a copy of local box image.
          env[:ui].info(I18n.t('vagrant_libvirt.uploading_volume'))

          # Create new volume in storage pool
          unless File.exist?(box_image_file)
            raise Vagrant::Errors::BoxNotFound, name: env[:machine].box.name
          end
          box_image_size = File.size(box_image_file) # B
          message = "Creating volume #{box_volume[:name]}"
          message << " in storage pool #{config.storage_pool_name}."
          @logger.info(message)

          @storage_volume_uid = storage_uid env
          @storage_volume_gid = storage_gid env

          begin
            fog_volume = env[:machine].provider.driver.connection.volumes.create(
              name: box_volume[:name],
              allocation: "#{box_image_size / 1024 / 1024}M",
              capacity: "#{box_volume[:virtual_size]}G",
              format_type: box_volume[:format],
              owner: @storage_volume_uid,
              group: @storage_volume_gid,
              pool_name: config.storage_pool_name
            )
          rescue Fog::Errors::Error => e
            raise Errors::FogCreateVolumeError,
                  error_message: e.message
          end

          # Upload box image to storage pool
          ret = upload_image(box_image_file, config.storage_pool_name,
                            box_volume[:name], env) do |progress|
            rewriting(env[:ui]) do |ui|
              ui.clear_line
              ui.report_progress(progress, box_image_size, false)
            end
          end

          # Clear the line one last time since the progress meter doesn't
          # disappear immediately.
          rewriting(env[:ui]) {|ui| ui.clear_line}

          # If upload failed or was interrupted, remove created volume from
          # storage pool.
          if env[:interrupted] || !ret
            begin
              fog_volume.destroy
            rescue
              nil
            end
          end
        end

        def call(env)
          # Verify box metadata for mandatory values.
          #
          # Verify disk number
          disks = env[:machine].box.metadata.fetch('disks', [])
          if disks.empty?
            disks.push({
              'path' => HandleBoxImage.get_default_box_image_path(0),
              'name' => HandleBoxImage.get_volume_name(env, 0),
              'virtual_size' => HandleBoxImage.get_virtual_size(env),
            })
          end
          HandleBoxImage.verify_virtual_size_in_disks(disks)

          # Support qcow2 format only for now, but other formats with backing
          # store capability should be usable.
          box_format = env[:machine].box.metadata['format']
          HandleBoxImage.verify_box_format(box_format)

          env[:box_volume_number] = disks.length()
          env[:box_volumes] = Array.new(env[:box_volume_number]) {|i| {
              :path => HandleBoxImage.get_box_image_path(
                env,
                disks[i].fetch('path', HandleBoxImage.get_default_box_image_path(i))
              ),
              :name => disks[i].fetch('name', HandleBoxImage.get_volume_name(env, i)),
              :virtual_size => disks[i]['virtual_size'],
              :format => HandleBoxImage.verify_box_format(
                disks[i].fetch('format', box_format),
                i
              )
            }
          }

          # Get config options
          config = env[:machine].provider_config
          box_image_files = []
          env[:box_volumes].each do |d|
            box_image_files.push(d[:path])
          end

          # Override box_virtual_size
          box_virtual_size = env[:box_volumes][0][:virtual_size]
          if config.machine_virtual_size
            if config.machine_virtual_size < box_virtual_size
              # Warn that a virtual size less than the box metadata size
              # is not supported and will be ignored
              env[:ui].warn I18n.t(
                'vagrant_libvirt.warnings.ignoring_virtual_size_too_small',
                  requested: config.machine_virtual_size, minimum: box_virtual_size
              )
            else
              env[:ui].info I18n.t('vagrant_libvirt.manual_resize_required')
              box_virtual_size = config.machine_virtual_size
            end
          end
          # save for use by later actions
          env[:box_volumes][0][:virtual_size] = box_virtual_size

          # while inside the synchronize block take care not to call the next
          # action in the chain, as must exit this block first to prevent
          # locking all subsequent actions as well.
          @@lock.synchronize do
            env[:box_volumes].each_index do |i|
              # Don't continue if image already exists in storage pool.
              box_volume = env[:machine].provider.driver.connection.volumes.all(
                name: env[:box_volumes][i][:name]
              ).first
              next if box_volume && box_volume.id

              send_box_image(env, config, box_image_files[i], env[:box_volumes][i])
            end
          end

          @app.call(env)
        end

        protected

        # Fog Libvirt currently doesn't support uploading images to storage
        # pool volumes. Use ruby-libvirt client instead.
        def upload_image(image_file, pool_name, volume_name, env)
          image_size = File.size(image_file) # B

          begin
            pool = env[:machine].provider.driver.connection.client.lookup_storage_pool_by_name(
              pool_name
            )
            volume = pool.lookup_volume_by_name(volume_name)
            stream = env[:machine].provider.driver.connection.client.stream
            volume.upload(stream, offset = 0, length = image_size)

            # Exception ProviderLibvirt::RetrieveError can be raised if buffer is
            # longer than length accepted by API send function.
            #
            # TODO: How to find out if buffer is too large and what is the
            # length that send function will accept?

            buf_size = 1024 * 250 # 250K
            progress = 0
            open(image_file, 'rb') do |io|
              while (buff = io.read(buf_size))
                sent = stream.send buff
                progress += sent
                yield progress
              end
            end
          rescue => e
            raise Errors::ImageUploadError,
                  error_message: e.message
          end

          progress == image_size
        end
      end
    end
  end
end
