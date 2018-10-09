require 'log4r'

module VagrantPlugins
  module ProviderLibvirt
    module Action
      # Action for create new box for libvirt provider
      class PackageDomain
        def initialize(app, env)
          @logger = Log4r::Logger.new('vagrant_libvirt::action::package_domain')
          @app = app
          env['package.files'] ||= {}
          env['package.output'] ||= 'package.box'
        end

        def call(env)
          env[:ui].info(I18n.t('vagrant_libvirt.package_domain'))
          libvirt_domain = env[:machine].provider.driver.connection.client.lookup_domain_by_uuid(
            env[:machine].id
          )
          domain = env[:machine].provider.driver.connection.servers.get(env[:machine].id.to_s)
          root_disk = domain.volumes.select do |x|
            x.name == libvirt_domain.name + '.img'
          end.first
          boxname = env['package.output']
          raise "#{boxname}: Already exists" if File.exist?(boxname)
          @tmp_dir = Dir.pwd + '/_tmp_package'
          @tmp_img = @tmp_dir + '/box.img'
          Dir.mkdir(@tmp_dir)
          env[:ui].info("Downloading #{root_disk.name} to #{@tmp_img}")
          ret = download_image(@tmp_img, env[:machine].provider_config.storage_pool_name,
                               root_disk.name, env) do |progress,image_size|
            env[:ui].clear_line
            env[:ui].report_progress(progress, image_size, false)
          end
          # Clear the line one last time since the progress meter doesn't
          # disappear immediately.
          env[:ui].clear_line
          backing = `qemu-img info "#{@tmp_img}" | grep 'backing file:' | cut -d ':' -f2`.chomp
          if backing
            env[:ui].info('Image has backing image, copying image and rebasing ...')
            `qemu-img rebase -p -b "" #{@tmp_img}`
          end
          # remove hw association with interface
          # working for centos with lvs default disks
          `virt-sysprep --no-logfile --operations defaults,-ssh-userdir -a #{@tmp_img}`
          # add any user provided file
          extra = ''
          @tmp_include = @tmp_dir + '/_include'
          if env['package.include']
            extra = './_include'
            Dir.mkdir(@tmp_include)
            env['package.include'].each do |f|
              env[:ui].info("Including user file: #{f}")
              FileUtils.cp(f, @tmp_include)
            end
          end
          if env['package.vagrantfile']
            extra = './_include'
            Dir.mkdir(@tmp_include) unless File.directory?(@tmp_include)
            env[:ui].info('Including user Vagrantfile')
            FileUtils.cp(env['package.vagrantfile'], @tmp_include + '/Vagrantfile')
          end
          Dir.chdir(@tmp_dir)
          info = JSON.parse(`qemu-img info --output=json #{@tmp_img}`)
          img_size = (Float(info['virtual-size'])/(1024**3)).ceil
          File.write(@tmp_dir + '/metadata.json', metadata_content(img_size))
          File.write(@tmp_dir + '/Vagrantfile', vagrantfile_content)
          assemble_box(boxname, extra)
          FileUtils.mv(@tmp_dir + '/' + boxname, '../' + boxname)
          FileUtils.rm_rf(@tmp_dir)
          env[:ui].info('Box created')
          env[:ui].info('You can now add the box:')
          env[:ui].info("vagrant box add #{boxname} --name any_comfortable_name")
          @app.call(env)
        end

        def assemble_box(boxname, extra)
          `tar cvzf "#{boxname}" --totals ./metadata.json ./Vagrantfile ./box.img #{extra}`
        end

        def vagrantfile_content
          <<-EOF
            Vagrant.configure("2") do |config|
              config.vm.provider :libvirt do |libvirt|
                libvirt.driver = "kvm"
                libvirt.host = ""
                libvirt.connect_via_ssh = false
                libvirt.storage_pool_name = "default"
              end
            end

            user_vagrantfile = File.expand_path('../_include/Vagrantfile', __FILE__)
            load user_vagrantfile if File.exists?(user_vagrantfile)
          EOF
        end

        def metadata_content(filesize)
          <<-EOF
            {
              "provider": "libvirt",
              "format": "qcow2",
              "virtual_size": #{filesize}
            }
          EOF
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
                  error_message: e.message
          end

          progress == image_size
        end
      end
    end
  end
end
