require 'log4r'

module VagrantPlugins
  module Libvirt
    module Action
      class CleanupDataDir
        def initialize(app, env)
          @logger = Log4r::Logger.new("vagrant_libvirt::action::cleanup_data_dir")
          @app = app
        end

        def call(env)
          # Remove file holding IP address
          ip_file_path = env[:machine].data_dir + 'ip'
          File.delete(ip_file_path) if File.exists?(ip_file_path)

          @app.call(env)
        end
      end
    end
  end
end
