require 'log4r'

module VagrantPlugins
  module ProviderLibvirt
    module Action
      class HandleStoragePool
        include VagrantPlugins::ProviderLibvirt::Util::ErbTemplate
        include VagrantPlugins::ProviderLibvirt::Util::StorageUtil


        @@lock = Mutex.new

        def initialize(app, _env)
          @logger = Log4r::Logger.new('vagrant_libvirt::action::handle_storage_pool')
          @app = app
        end

        def call(env)
          # Get config options.
          config = env[:machine].provider_config

          # while inside the synchronize block take care not to call the next
          # action in the chain, as must exit this block first to prevent
          # locking all subsequent actions as well.
          @@lock.synchronize do
            # Check for storage pool, where box image should be created
            break if ProviderLibvirt::Util::Collection.find_matching(
              env[:machine].provider.driver.connection.pools.all, config.storage_pool_name
            )

            @logger.info("No storage pool '#{config.storage_pool_name}' is available.")

            # If user specified other pool than default, don't create default
            # storage pool, just write error message.
            raise Errors::NoStoragePool if config.storage_pool_name != 'default'

            @logger.info("Creating storage pool 'default'")

            # Fog libvirt currently doesn't support creating pools. Use
            # ruby-libvirt client directly.
            begin
              @storage_pool_path = storage_pool_path(env)
              @storage_pool_uid = storage_uid(env)
              @storage_pool_gid = storage_gid(env)
              libvirt_pool = env[:machine].provider.driver.connection.client.define_storage_pool_xml(
                to_xml('default_storage_pool')
              )
              libvirt_pool.build
              libvirt_pool.create
            rescue => e
              raise Errors::CreatingStoragePoolError,
                    error_message: e.message
            end
            raise Errors::NoStoragePool unless libvirt_pool
          end

          @app.call(env)
        end
      end
    end
  end
end
