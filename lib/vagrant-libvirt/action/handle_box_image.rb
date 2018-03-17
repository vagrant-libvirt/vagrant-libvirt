require 'log4r'

module VagrantPlugins
  module ProviderLibvirt
    module Action
      class HandleBoxImage
        include VagrantPlugins::ProviderLibvirt::Util::ErbTemplate
        include VagrantPlugins::ProviderLibvirt::Util::StorageUtil


        @@lock = Mutex.new

        def initialize(app, _env)
          @logger = Log4r::Logger.new('vagrant_libvirt::action::handle_box_image')
          @app = app
        end

        def call(env)
          # Verify box metadata for mandatory values.
          #
          # Virtual size has to be set for allocating space in storage pool.
          box_virtual_size = env[:machine].box.metadata['virtual_size']
          raise Errors::NoBoxVirtualSizeSet if box_virtual_size.nil?

          # Support qcow2 format only for now, but other formats with backing
          # store capability should be usable.
          box_format = env[:machine].box.metadata['format']
          if box_format.nil?
            raise Errors::NoBoxFormatSet
          elsif box_format != 'qcow2'
            raise Errors::WrongBoxFormatSet
          end

          # Get config options
          config = env[:machine].provider_config
          box_image_file = env[:machine].box.directory.join('box.img').to_s
          env[:box_volume_name] = env[:machine].box.name.to_s.dup.gsub('/', '-VAGRANTSLASH-')
          env[:box_volume_name] << "_vagrant_box_image_#{
          begin
            env[:machine].box.version.to_s
          rescue
            ''
          end}.img"

          # Override box_virtual_size
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
          env[:box_virtual_size] = box_virtual_size

          # while inside the synchronize block take care not to call the next
          # action in the chain, as must exit this block first to prevent
          # locking all subsequent actions as well.
          @@lock.synchronize do
            # Don't continue if image already exists in storage pool.
            break if ProviderLibvirt::Util::Collection.find_matching(
              env[:machine].provider.driver.connection.volumes.all, env[:box_volume_name]
            )

            # Box is not available as a storage pool volume. Create and upload
            # it as a copy of local box image.
            env[:ui].info(I18n.t('vagrant_libvirt.uploading_volume'))

            # Create new volume in storage pool
            unless File.exist?(box_image_file)
              raise Vagrant::Errors::BoxNotFound, name: env[:machine].box.name
            end
            box_image_size = File.size(box_image_file) # B
            message = "Creating volume #{env[:box_volume_name]}"
            message << " in storage pool #{config.storage_pool_name}."
            @logger.info(message)

            if config.qemu_use_session
              begin
                @name = env[:box_volume_name]
                @allocation = "#{box_image_size / 1024 / 1024}M"
                @capacity = "#{box_virtual_size}G"
                @format_type = box_format ? box_format : 'raw'

                @storage_volume_uid = storage_uid env
                @storage_volume_gid = storage_gid env

                libvirt_client = env[:machine].provider.driver.connection.client
                libvirt_pool = libvirt_client.lookup_storage_pool_by_name(
                  config.storage_pool_name
                )
                libvirt_volume = libvirt_pool.create_volume_xml(
                  to_xml('default_storage_volume')
                )
              rescue => e
                raise Errors::CreatingVolumeError,
                      error_message: e.message
              end
            else
              begin
                fog_volume = env[:machine].provider.driver.connection.volumes.create(
                  name: env[:box_volume_name],
                  allocation: "#{box_image_size / 1024 / 1024}M",
                  capacity: "#{box_virtual_size}G",
                  format_type: box_format,
                  pool_name: config.storage_pool_name
                )
              rescue Fog::Errors::Error => e
                raise Errors::FogCreateVolumeError,
                      error_message: e.message
              end
            end

            # Upload box image to storage pool
            ret = upload_image(box_image_file, config.storage_pool_name,
                               env[:box_volume_name], env) do |progress|
              env[:ui].clear_line
              env[:ui].report_progress(progress, box_image_size, false)
            end

            # Clear the line one last time since the progress meter doesn't
            # disappear immediately.
            env[:ui].clear_line

            # If upload failed or was interrupted, remove created volume from
            # storage pool.
            if env[:interrupted] || !ret
              begin
                if config.qemu_use_session
                  libvirt_volume.delete
                else
                  fog_volume.destroy
                end
              rescue
                nil
              end
            end
          end

          @app.call(env)
        end

        def split_size_unit(text)
          if text.kind_of? Integer
            # if text is an integer, match will fail
            size    = text
            unit    = 'G'
          else
            matcher = text.match(/(\d+)(.+)/)
            size    = matcher[1]
            unit    = matcher[2]
          end
          [size, unit]
        end

        protected

        # Fog libvirt currently doesn't support uploading images to storage
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
