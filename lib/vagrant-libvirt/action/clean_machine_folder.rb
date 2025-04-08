# frozen_string_literal: true

require 'log4r'

module VagrantPlugins
  module ProviderLibvirt
    module Action
      class CleanMachineFolder

        def initialize(app, env, options=nil)
          @logger = Log4r::Logger.new('vagrant_libvirt::action::create_domain')
          @app = app
          @ui = env[:ui]
          @quiet = (options || {}).fetch(:quiet, false)
        end

        def call(env)
          machine_folder = env[:machine].data_dir

          @ui.info("Deleting the machine folder") unless @quiet

          @logger.debug("Recursively removing: #{machine_folder}")
          FileUtils.rm_rf(machine_folder, :secure => true)
          # need to recreate to prevent exception during a cancelled up
          FileUtils.mkdir_p(machine_folder)

          @app.call(env)
        end
      end
    end
  end
end
