require 'log4r'

module VagrantPlugins
  module ProviderLibvirt
    module Action
      class RemoveLibvirtImage
        def initialize(app, _env)
          @logger = Log4r::Logger.new('vagrant_libvirt::action::remove_libvirt_image')
          @app = app
        end

        def call(env)
          env[:ui].info('Vagrant-libvirt plugin removed box only from you LOCAL ~/.vagrant/boxes directory')
          env[:ui].info('From libvirt storage pool you have to delete image manually(virsh, virt-manager or by any other tool)')
          @app.call(env)
        end
      end
    end
  end
end
