require "log4r"
require 'nokogiri'
require "digest/md5"

module VagrantPlugins
  module ProviderLibvirt
    module Action
      class ImportMaster
        def initialize(app, env)
          @app = app
          @logger = Log4r::Logger.new("vagrant_libvirt::action::vm::create_master")
        end

        def call(env)
          # If we don't have a box, nothing to do
          if !env[:machine].box
            return @app.call(env)
          end

          # Do the import while locked so that nobody else imports
          # a master at the same time. This is a no-op if we already
          # have a master that exists.
          lock_key = Digest::MD5.hexdigest(env[:machine].box.name)
          env[:machine].env.lock(lock_key, retry: true) do
            import_master(env)
          end

          # If we got interrupted, then the import could have been
          # interrupted and its not a big deal. Just return out.
          if env[:interrupted]
            @logger.info("Import of master VM was interrupted -> exiting.")
            return
          end

          # Import completed successfully. Continue the chain
          @app.call(env)
        end

        protected

        def import_master(env)
          box_directory = env[:machine].box.directory
          box_xml_file = box_directory.join("box.xml")
          box_img_file = box_directory.join("box.img")

          # If we don't have `box.xml` but legacy `box.img`, copy a
          # simple default for it.
          if !box_xml_file.file? && box_img_file.file?
            FileUtils.cp(File.join(File.dirname(__FILE__), '../templates/box.xml'), box_directory)
          end

          @logger.info("Importing box.xml")
          env[:box_xml] = Nokogiri::XML(File.open(box_xml_file))
        end
      end
    end
  end
end
