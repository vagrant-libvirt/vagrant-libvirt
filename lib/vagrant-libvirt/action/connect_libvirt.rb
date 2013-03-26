require 'fog'
require 'log4r'

module VagrantPlugins
  module Libvirt
    module Action
      class ConnectLibvirt
        def initialize(app, env)
          @logger = Log4r::Logger.new("vagrant_libvirt::action::connect_libvirt")
          @app = app
        end

        def call(env)

          # If already connected to libvirt, just use it and don't connect
          # again.
          if Libvirt.libvirt_connection
            env[:libvirt_compute] = Libvirt.libvirt_connection
            return @app.call(env)
          end
          
          # Get config options for libvirt provider.
          config = env[:machine].provider_config

          # Setup connection uri.
          uri = config.driver
          if config.connect_via_ssh
            uri << '+ssh://'
            if config.username
              uri << config.username + '@'
            end

            if config.host
              uri << config.host
            else
              uri << 'localhost'
            end
          else
            uri << '://'
            uri << config.host if config.host
          end                
          uri << '/system?no_verify=1'

          conn_attr = {}
          conn_attr[:provider] = 'libvirt'
          conn_attr[:libvirt_uri] = uri
          conn_attr[:libvirt_username] = config.username if config.username
          conn_attr[:libvirt_password] = config.password if config.password
          
          # Setup command for retrieving IP address for newly created machine
          # with some MAC address. Get it via arp table. This solution doesn't
          # require arpwatch to be installed.
          conn_attr[:libvirt_ip_command] = "arp -an | grep $mac | sed '"
          conn_attr[:libvirt_ip_command] << 's/.*(\([0-9\.]*\)).*/\1/'
          conn_attr[:libvirt_ip_command] << "'"

          @logger.info("Connecting to Libvirt (#{uri}) ...")
          begin
            env[:libvirt_compute] = Fog::Compute.new(conn_attr)
          rescue Fog::Errors::Error => e
            raise Errors::FogLibvirtConnectionError,
              :error_message => e.message
          end
          Libvirt.libvirt_connection = env[:libvirt_compute]

          @app.call(env)
        end
      end
    end
  end
end

