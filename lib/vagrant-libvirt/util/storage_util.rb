# frozen_string_literal: true

require 'vagrant-libvirt/util/ui'

module VagrantPlugins
  module ProviderLibvirt
    module Util
      module StorageUtil
        include VagrantPlugins::ProviderLibvirt::Util::Ui

        def storage_uid(env)
          env[:machine].provider_config.qemu_use_session ? Process.uid : 0
        end

        def storage_gid(env)
          env[:machine].provider_config.qemu_use_session ? Process.gid : 0
        end

        def storage_pool_path(env)
          if env[:machine].provider_config.storage_pool_path
            env[:machine].provider_config.storage_pool_path
          elsif env[:machine].provider_config.qemu_use_session
            File.expand_path('~/.local/share/libvirt/images')
          else
            '/var/lib/libvirt/images'
          end
        end

        def storage_send_box_image(env, config, box_image_file, box_volume)
          # Box is not available as a storage pool volume. Create and upload
          # it as a copy of local box image.
          env[:ui].info(I18n.t('vagrant_libvirt.uploading_volume'))

          # Create new volume in storage pool
          unless File.exist?(box_image_file)
            raise Vagrant::Errors::BoxNotFound, name: env[:machine].box.name
          end
          box_image_size = File.size(box_image_file) # B
          begin
            fog_volume = env[:machine].provider.driver.connection.volumes.create(
              name: box_volume[:name],
              allocation: "#{box_image_size / 1024 / 1024}M",
              capacity: "#{box_volume[:virtual_size].to_B}B",
              format_type: box_volume[:format],
              owner: storage_uid(env),
              group: storage_gid(env),
              pool_name: config.storage_pool_name
            )
          rescue Fog::Errors::Error => e
            raise Errors::FogCreateVolumeError,
                  error_message: e.message
          end

          # Upload box image to storage pool
          ret = storage_upload_image(env, box_image_file,
                                    config.storage_pool_name,
                                    box_volume[:name]) do |progress|
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

        # Fog Libvirt currently doesn't support uploading images to storage
        # pool volumes. Use ruby-libvirt client instead.
        def storage_upload_image(env, image_file, pool_name, volume_name)
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
