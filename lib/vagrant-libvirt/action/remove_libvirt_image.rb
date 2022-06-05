# frozen_string_literal: true

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
          return @app.call(env) unless env[:box_removed].provider == :libvirt

          env[:ui].info("Vagrant-libvirt plugin removed box only from #{env[:env].boxes.directory} directory")
          env[:ui].info('From Libvirt storage pool you have to delete image manually(virsh, virt-manager or by any other tool)')
          @app.call(env)
        end
      end
    end
  end
end
