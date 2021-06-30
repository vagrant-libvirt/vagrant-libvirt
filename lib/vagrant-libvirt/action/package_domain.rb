# frozen_string_literal: true

require 'fileutils'
require 'log4r'

class String
  def unindent
    gsub(/^#{scan(/^\s*/).min_by{|l|l.length}}/, "")
  end
end

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
          root_disk = domain.volumes.select do |x|
            x.name == libvirt_domain.name + '.img'
          end.first
          raise Errors::NoDomainVolume if root_disk.nil?

          package_directory = env["package.directory"]
          domain_img = package_directory + '/box.img'
          env[:ui].info("Downloading #{root_disk.name} to #{domain_img}")
          ret = download_image(domain_img, env[:machine].provider_config.storage_pool_name,
                               root_disk.name, env) do |progress,image_size|
            rewriting(env[:ui]) do |ui|
              ui.clear_line
              ui.report_progress(progress, image_size, false)
            end
          end
          # Clear the line one last time since the progress meter doesn't
          # disappear immediately.
          rewriting(env[:ui]) {|ui| ui.clear_line}

          # Prep domain disk
          backing = `qemu-img info "#{domain_img}" | grep 'backing file:' | cut -d ':' -f2`.chomp
          if backing
            env[:ui].info('Image has backing image, copying image and rebasing ...')
            `qemu-img rebase -p -b "" #{domain_img}`
          end
          # remove hw association with interface
          # working for centos with lvs default disks
          `virt-sysprep --no-logfile --operations #{@operations} -a #{domain_img} #{@options}`
          `virt-sparsify --in-place #{domain_img}`

          # metadata / Vagrantfile
          info = JSON.parse(`qemu-img info --output=json #{domain_img}`)
          img_size = (Float(info['virtual-size'])/(1024**3)).ceil
          File.write(package_directory + '/metadata.json', metadata_content(img_size))
          File.write(package_directory + '/Vagrantfile', vagrantfile_content(env))

          @app.call(env)
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

        def metadata_content(filesize)
          <<-EOF.unindent
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
