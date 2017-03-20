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
          if File.readable?(root_disk.path)
            backing = `qemu-img info "#{root_disk.path}" | grep 'backing file:' | cut -d ':' -f2`.chomp
          else
            env[:ui].error("Require set read access to #{root_disk.path}. sudo chmod a+r #{root_disk.path}")
            FileUtils.rm_rf(@tmp_dir)
            raise 'Have no access'
          end
          env[:ui].info('Image has backing image, copying image and rebasing ...')
          FileUtils.cp(root_disk.path, @tmp_img)
          `qemu-img rebase -p -b "" #{@tmp_img}`
          # remove hw association with interface
          # working for centos with lvs default disks
          `virt-sysprep --no-logfile --operations defaults,-ssh-userdir -a #{@tmp_img}`
          Dir.chdir(@tmp_dir)
          info = JSON.parse(`qemu-img info --output=json #{@tmp_img}`)
          img_size = (Float(info['virtual-size'])/(1024**3)).ceil
          File.write(@tmp_dir + '/metadata.json', metadata_content(img_size))
          File.write(@tmp_dir + '/Vagrantfile', vagrantfile_content)
          assebmle_box(boxname)
          FileUtils.mv(@tmp_dir + '/' + boxname, '../' + boxname)
          FileUtils.rm_rf(@tmp_dir)
          env[:ui].info('Box created')
          env[:ui].info('You can now add the box:')
          env[:ui].info("vagrant box add #{boxname} --name any_comfortable_name")
          @app.call(env)
        end

        def assebmle_box(boxname)
          `tar cvzf "#{boxname}" --totals ./metadata.json ./Vagrantfile ./box.img`
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
      end
    end
  end
end
