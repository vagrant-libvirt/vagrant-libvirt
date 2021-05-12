require 'fileutils'
require 'log4r'

module VagrantPlugins
  module ProviderLibvirt
    module Action
      # Action for create new box for Libvirt provider
      class PackageDomain
        include VagrantPlugins::ProviderLibvirt::Util::Ui

        def initialize(app, env)
          @logger = Log4r::Logger.new('vagrant_libvirt::action::package_domain')
          @app = app
          env['package.files'] ||= {}
          env['package.output'] ||= 'package.box'
        end

        def call(env)
          env[:ui].info(I18n.t('vagrant_libvirt.package_domain'))
          domain = env[:machine].provider.driver.get_domain(env[:machine])

          boxname = env['package.output']
          raise "#{boxname}: Already exists" if File.exist?(boxname)

          options = ENV.fetch('VAGRANT_LIBVIRT_VIRT_SYSPREP_OPTIONS', '')
          operations = ENV.fetch('VAGRANT_LIBVIRT_VIRT_SYSPREP_OPERATIONS', 'defaults,-ssh-userdir,-customize')

          @tmp_dir = Dir.mktmpdir(nil, Dir.pwd)
          domain.volumes.each_with_index do |volume, index|
            @tmp_img = File.join(@tmp_dir, (index == 0 ? "box.img" : "box-sd#{('a'..'z').to_a[index]}"))
            env[:ui].info("Downloading #{volume.name} to #{@tmp_img}")
            ret = download_image(@tmp_img, env[:machine].provider_config.storage_pool_name,
                                 volume.name, env) do |progress,image_size|
              rewriting(env[:ui]) do |ui|
                ui.clear_line
                ui.report_progress(progress, image_size, false)
              end
            end

            # Clear the line one last time since the progress meter doesn't
            # disappear immediately.
            rewriting(env[:ui]) {|ui| ui.clear_line}
            backing = `qemu-img info "#{@tmp_img}" | grep 'backing file:' | cut -d ':' -f2`.chomp
            if backing
              env[:ui].info('Image has backing image, copying image and rebasing ...')
              `qemu-img rebase -p -b "" #{@tmp_img}`
            end
          
            if index == 0
              # reset image with `virt-sysprep`
              env[:ui].info('Resetting image with `virt-sysprep`...')
              `virt-sysprep --no-logfile --operations #{operations} -a #{@tmp_img} #{options}`
            end

            # spare image with `virt-sparsify`
            env[:ui].info('Sparsing image with `virt-sparsify`...')
            `virt-sparsify --in-place #{@tmp_img}`

            # compress image with `qemu-img`
            env[:ui].info('Compress image with `qemu-img`...')
            `qemu-img convert -f qcow2 -O qcow2 -c #{@tmp_img} #{@tmp_img}.convert`
            FileUtils.mv("#{@tmp_img}.convert", "#{@tmp_img}")
          end

          # copy templates
          FileUtils.cp(File.join(File.dirname(__FILE__), '../templates/metadata.json'), @tmp_dir)
          FileUtils.cp(File.join(File.dirname(__FILE__), '../templates/Vagrantfile'), @tmp_dir)
          FileUtils.cp(File.join(File.dirname(__FILE__), '../templates/box.xml'), @tmp_dir)

          # add any user provided file
          if env['package.include']
            env['package.include'].each do |f|
              env[:ui].info("Including user file: #{f}")
              FileUtils.cp(f, @tmp_dir)
            end
          end
          if env['package.vagrantfile']
            env[:ui].info('Including user Vagrantfile')
            FileUtils.cp(env['package.vagrantfile'], @tmp_dir + '/_Vagrantfile')
          end

          Dir.chdir(@tmp_dir)
          env[:ui].info('Creating box, tarring and gzipping...')
          `tar zcvf ../#{boxname} ./*`
          FileUtils.rm_rf(@tmp_dir)
          env[:ui].info("#{boxname} created")
          env[:ui].info("You can now add the box:")
          env[:ui].info("  'vagrant box add #{boxname} --name any_comfortable_name'")
          @app.call(env)
        end

        protected

        # Fog libvirt currently doesn't support downloading images from storage
        # pool volumes. Use ruby-libvirt client instead.
        def download_image(image_file, pool_name, volume_name, env)
          begin
            pool = env[:machine].provider.driver.connection.client.lookup_storage_pool_by_name(
              pool_name
            )
            volume = pool.lookup_volume_by_name(volume_name)
            image_size = volume.info.allocation # B

            stream = env[:machine].provider.driver.connection.client.stream

            # Use length of 0 to download remaining contents after offset
            volume.download(stream, offset = 0, length = 0)

            buf_size = 1024 * 250 # 250K, copied from upload_image in handle_box_image.rb
            progress = 0
            retval = stream.recv(buf_size)
            open(image_file, 'wb') do |io|
              while (retval.at(0) > 0)
                recvd = io.write(retval.at(1))
                progress += recvd
                yield [progress, image_size]
                retval = stream.recv(buf_size)
              end
            end
          rescue => e
            raise Errors::ImageDownloadError,
                  volume_name: volume_name,
                  pool_name: pool_name,
                  error_message: e.message
          end

          progress == image_size
        end
      end
    end
  end
end
