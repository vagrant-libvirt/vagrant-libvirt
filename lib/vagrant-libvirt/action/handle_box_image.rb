require 'log4r'
require 'nokogiri'

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

        def call(env)
          # Get config options
          config = env[:machine].provider_config
          
          box_image_files = []
          begin
            box_xml = env[:machine].box.directory.join('box.xml').to_s
            xml = Nokogiri::XML(File.open(box_xml))
            xml.xpath('/domain/devices/disk/source/@file').each_with_index do |volume, index|
              basename = File.basename(volume)
              box_image_files << env[:machine].box.directory.join(basename).to_s
            end
          rescue
            box_image_files << env[:machine].box.directory.join('box.img').to_s
          end

          env[:box_volume_name] = []
          env[:box_virtual_size] = []
          env[:box_format] = []
          box_image_files.each_with_index do |box_image_file, index|
            # Verify box metadata for mandatory values.
            #
            # Virtual size has to be set for allocating space in storage pool.
            box_virtual_size = `qemu-img info #{box_image_file} | grep 'virtual size:' | sed 's/^.*: \\([0-9]*\\) GiB.*$/\\1/g'`.chomp
            raise Errors::NoBoxVirtualSizeSet if box_virtual_size.nil?
  
            # Support qcow2 format only for now, but other formats with backing
            # store capability should be usable.
            box_format = `qemu-img info #{box_image_file} | grep 'file format:' | sed 's/^.*: \\(.*\\)$/\\1/g'`.chomp
            if box_format.nil?
              raise Errors::NoBoxFormatSet
            elsif box_format != 'qcow2'
              raise Errors::WrongBoxFormatSet
            end

            if index == 0
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
            end

            # save for use by later actions
            device = (index + 1).vdev.to_s
            env[:box_volume_name][index] = env[:machine].box.name.to_s.dup.gsub('/', '-VAGRANTSLASH-')
            env[:box_volume_name][index] << "-vagrant_box_image-"
            env[:box_volume_name][index] << "#{env[:machine].box.version.to_s}-#{device}.qcow2"
            env[:box_virtual_size][index] = box_virtual_size
            env[:box_format][index] = box_format
          end

          # while inside the synchronize block take care not to call the next
          # action in the chain, as must exit this block first to prevent
          # locking all subsequent actions as well.
          box_image_files.each_with_index do |box_image_file, index|
            @@lock.synchronize do
              # Don't continue if image already exists in storage pool.
              box_volume = env[:machine].provider.driver.connection.volumes.all(
                name: env[:box_volume_name][index]
              ).first
              break if box_volume && box_volume.id
  
              # Box is not available as a storage pool volume. Create and upload
              # it as a copy of local box image.
              env[:ui].info(I18n.t('vagrant_libvirt.uploading_volume'))
  
              # Create new volume in storage pool
              unless File.exist?(box_image_file)
                raise Vagrant::Errors::BoxNotFound, name: env[:machine].box.name
              end
              box_image_size = File.size(box_image_file) # B
              message = "Creating volume #{env[:box_volume_name][index]}"
              message << " in storage pool #{config.storage_pool_name}."
              @logger.info(message)
  
              @storage_volume_uid = storage_uid env
              @storage_volume_gid = storage_gid env
  
              begin
                fog_volume = env[:machine].provider.driver.connection.volumes.create(
                  name: env[:box_volume_name][index],
                  allocation: "#{box_image_size / 1024 / 1024}M",
                  capacity: "#{env[:box_virtual_size][index]}G",
                  format_type: env[:box_format][index],
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
                                 env[:box_volume_name][index], env) do |progress|
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
