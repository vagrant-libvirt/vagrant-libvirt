require "pathname"

require "log4r"

module VagrantPlugins
  module Libvirt
    module Action
      class ShareFolders
        def initialize(app, env)
          @logger = Log4r::Logger.new("vagrant::action::vm::share_folders")
          @app    = app
        end

        def call(env)
          @env = env

          prepare_folders
          create_metadata

          @app.call(env)
        end

        # This method returns an actual list of shared
        # folders to create and their proper path.
        def shared_folders
          {}.tap do |result|
            @env[:machine].config.vm.synced_folders.each do |id, data|
              # Ignore NFS shared folders
              next if !data[:nfs]

              # convert to NFS share
              #data[:nfs] = true

              # This to prevent overwriting the actual shared folders data
              result[id] = data.dup
            end
          end
        end

        # Prepares the shared folders by verifying they exist and creating them
        # if they don't.
        def prepare_folders
          shared_folders.each do |id, options|
            hostpath = Pathname.new(options[:hostpath]).expand_path(@env[:root_path])

            if !hostpath.directory? && options[:create]
              # Host path doesn't exist, so let's create it.
              @logger.debug("Host path doesn't exist, creating: #{hostpath}")

              begin
                hostpath.mkpath
              rescue Errno::EACCES
                raise Vagrant::Errors::SharedFolderCreateFailed,
                  :path => hostpath.to_s
              end
            end
          end
        end

        def create_metadata
          @env[:ui].info I18n.t("vagrant.actions.vm.share_folders.creating")

          folders = []
          shared_folders.each do |id, data|
            folders << {
              :name => id,
              :hostpath => File.expand_path(data[:hostpath], @env[:root_path]),
              :transient => data[:transient]
            }
          end
        end

      end
    end
  end
end
