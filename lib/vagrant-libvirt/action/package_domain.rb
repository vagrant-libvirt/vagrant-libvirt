# frozen_string_literal: true

require 'fileutils'
require 'log4r'

require 'vagrant-libvirt/util/unindent'

module VagrantPlugins
  module ProviderLibvirt
    module Action
      # Action for create new box for Libvirt provider
      class PackageDomain
        include VagrantPlugins::ProviderLibvirt::Util::Ui


        def initialize(app, env)
          @logger = Log4r::Logger.new('vagrant_libvirt::action::package_domain')
          @app = app

          @options = ENV.fetch('VAGRANT_LIBVIRT_VIRT_SYSPREP_OPTIONS', '')
          @operations = ENV.fetch('VAGRANT_LIBVIRT_VIRT_SYSPREP_OPERATIONS', 'defaults,-ssh-userdir,-ssh-hostkeys,-customize')
        end

        def call(env)
          env[:ui].info(I18n.t('vagrant_libvirt.package_domain'))
          libvirt_domain = env[:machine].provider.driver.connection.client.lookup_domain_by_uuid(
            env[:machine].id
          )
          domain = env[:machine].provider.driver.connection.servers.get(env[:machine].id.to_s)

          volumes = domain.volumes.select { |x| !x.nil? }
          root_disk = volumes.select do |x|
            x.name == libvirt_domain.name + '.img'
          end.first
          raise Errors::NoDomainVolume if root_disk.nil?

          package_func = method(:package_v1)

          box_format = ENV.fetch('VAGRANT_LIBVIRT_BOX_FORMAT_VERSION', nil)

          case box_format
          when nil
            if volumes.length() > 1
              msg = "Detected more than one volume for machine, in the future this will switch to using the v2 "
              msg += "box format v2 automatically."
              msg += "\nIf you want to include the additional disks attached when packaging please set the "
              msg += "env variable VAGRANT_LIBVIRT_BOX_FORMAT_VERSION=v2 to use the new format. If you want "
              msg += "to ensure that your box uses the old format for single disk only, please set the "
              msg += "environment variable explicitly to 'v1'"
              env[:ui].warn(msg)
            end
          when 'v2'
            package_func = method(:package_v2)
          when 'v1'
          else
            env[:ui].warn("Unrecognized value for 'VAGRANT_LIBVIRT_BOX_FORMAT_VERSION', defaulting to v1")
          end

          metadata = package_func.call(env, volumes)

          # metadata / Vagrantfile
          package_directory = env["package.directory"]
          File.write(package_directory + '/metadata.json', metadata)
          File.write(package_directory + '/Vagrantfile', vagrantfile_content(env))

          @app.call(env)
        end

        def package_v1(env, volumes)
          domain_img = download_volume(env, volumes.first, 'box.img')

          sysprep_domain(domain_img)
          sparsify_volume(domain_img)

          info = JSON.parse(`qemu-img info --output=json #{domain_img}`)
          img_size = (Float(info['virtual-size'])/(1024**3)).ceil

          return metadata_content_v1(img_size)
        end

        def package_v2(env, volumes)
          disks = []
          volumes.each_with_index do |vol, idx|
            disk = {:path => "box_#{idx+1}.img"}
            volume_img = download_volume(env, vol, disk[:path])

            if idx == 0
              sysprep_domain(volume_img)
            end

            sparsify_volume(volume_img)

            disks.push(disk)
          end

          return metadata_content_v2(disks)
        end

        def vagrantfile_content(env)
          include_vagrantfile = ""

          if env["package.vagrantfile"]
            include_vagrantfile = <<-EOF

              # Load include vagrant file if it exists after the auto-generated
              # so it can override any of the settings
              include_vagrantfile = File.expand_path("../include/_Vagrantfile", __FILE__)
              load include_vagrantfile if File.exist?(include_vagrantfile)
            EOF
          end

          <<-EOF.unindent
            Vagrant.configure("2") do |config|
              config.vm.provider :libvirt do |libvirt|
                libvirt.driver = "kvm"
              end
            #{include_vagrantfile}
            end
          EOF
        end

        def metadata_content_v1(filesize)
          <<-EOF.unindent
            {
              "provider": "libvirt",
              "format": "qcow2",
              "virtual_size": #{filesize}
            }
          EOF
        end

        def metadata_content_v2(disks)
          data = {
            "provider": "libvirt",
            "format": "qcow2",
            "disks": disks.each do |disk|
              {'path': disk[:path]}
            end
          }
          JSON.pretty_generate(data)
        end

        protected

        def sparsify_volume(volume_img)
          `virt-sparsify --in-place #{volume_img}`
        end

        def sysprep_domain(domain_img)
          # remove hw association with interface
          # working for centos with lvs default disks
          `virt-sysprep --no-logfile --operations #{@operations} -a #{domain_img} #{@options}`
        end

        def download_volume(env, volume, disk_path)
          package_directory = env["package.directory"]
          volume_img = package_directory + '/' + disk_path
          env[:ui].info("Downloading #{volume.name} to #{volume_img}")
          download_image(volume_img, env[:machine].provider_config.storage_pool_name,
                               volume.name, env) do |progress,image_size|
            rewriting(env[:ui]) do |ui|
              ui.clear_line
              ui.report_progress(progress, image_size, false)
            end
          end
          # Clear the line one last time since the progress meter doesn't
          # disappear immediately.
          rewriting(env[:ui]) {|ui| ui.clear_line}

          # Prep domain disk
          backing = `qemu-img info "#{volume_img}" | grep 'backing file:' | cut -d ':' -f2`.chomp
          if backing
            env[:ui].info('Image has backing image, copying image and rebasing ...')
            `qemu-img rebase -p -b "" #{volume_img}`
          end

          return volume_img
        end

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
