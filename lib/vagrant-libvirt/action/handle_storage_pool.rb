require 'log4r'

module VagrantPlugins
  module Libvirt
    module Action
      class HandleStoragePool
        include VagrantPlugins::Libvirt::Util::ErbTemplate

        def initialize(app, env)
          @logger = Log4r::Logger.new("vagrant_libvirt::action::handle_storage_pool")
          @app = app
        end

        def call(env)
          # Get config options.
          config = env[:machine].provider_config

          # Check for storage pool, where box image should be created
          fog_pool = Libvirt::Util::Collection.find_matching(
            env[:libvirt_compute].pools.all, config.storage_pool_name)
          return @app.call(env) if fog_pool

          @logger.info("No storage pool '#{config.storage_pool_name}' is available.")

          # If user specified other pool than default, don't create default
          # storage pool, just write error message.
          raise Errors::NoStoragePool if config.storage_pool_name != 'default'

          @logger.info("Creating storage pool 'default'")

          # Fog libvirt currently doesn't support creating pools. Use
          # ruby-libvirt client directly.
          begin
            libvirt_pool = env[:libvirt_compute].client.create_storage_pool_xml(
              to_xml('default_storage_pool'))
          rescue => e
            raise Errors::CreatingStoragePoolError,
              :error_message => e.message
          end
          raise Errors::NoStoragePool if !libvirt_pool

          @app.call(env)
        end

      end
    end
  end
end

