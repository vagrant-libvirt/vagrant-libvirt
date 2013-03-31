require 'log4r'

module VagrantPlugins
  module Libvirt
    module Action

      class Suspend
        def initialize(app, env)
          @logger = Log4r::Logger.new("vagrant_libvirt::action::create_domain")
          @app = app
        end

        # make pause
        def call(env)
          vmid = env[:machine].id.to_s.chomp
          domain = env[:libvirt_compute].servers.get(vmid)
          domain.suspend
          @logger.info("Machine #{vmid} is suspended ")
          @app.call(env)
        end
      end

    end
  end
end
