# frozen_string_literal: true

require 'log4r'
# require 'log4r/yamlconfigurator'

module VagrantPlugins
  module ProviderLibvirt
    module Action
      class RemoveStaleVolume
        def initialize(app, _env)
          #          log4r_config= YAML.load_file(File.join(File.dirname(__FILE__),"log4r.yaml"))
          #          log_cfg = Log4r::YamlConfigurator
          #          log_cfg.decode_yaml( log4r_config['log4r_config'] )

          @logger = Log4r::Logger.new('vagrant_libvirt::action::remove_stale_volume')
          @app = app
        end

        def call(env)
          # Remove stale server volume
          config = env[:machine].provider_config
          # Check for storage pool, where box image should be created
          fog_pool = env[:machine].provider.driver.connection.pools.all(
            name: config.storage_pool_name
          ).first

          env[:result] = nil

          if not fog_pool
            @logger.debug("**** Pool #{config.storage_pool_name} not found")
            return @app.call(env)
          end

          @logger.debug("**** Pool #{fog_pool.name}")

          # This is name of newly created image for vm.
          name = "#{env[:domain_name]}.img"
          @logger.debug("**** Volume name #{name}")

          # remove root storage
          box_volume = env[:machine].provider.driver.connection.volumes.all(
            name: name
          ).find { |x| x.pool_name == fog_pool.name }
          if box_volume && box_volume.id
            env[:ui].info(I18n.t('vagrant_libvirt.remove_stale_volume'))
            @logger.info("Deleting volume #{box_volume.key}")
            box_volume.destroy
            env[:result] = box_volume
          else
            @logger.debug("**** Volume #{name} not found in pool #{fog_pool.name}")
          end
          # Continue the middleware chain.
          @app.call(env)
        end
      end
    end
  end
end
