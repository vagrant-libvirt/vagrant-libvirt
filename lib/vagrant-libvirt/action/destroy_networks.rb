require 'log4r'
require 'nokogiri'

module VagrantPlugins
  module ProviderLibvirt
    module Action
      # Destroy all networks created for this specific domain. Skip
      # removing if network has still active connections.
      class DestroyNetworks
        def initialize(app, _env)
          @logger = Log4r::Logger.new('vagrant_libvirt::action::destroy_networks')
          @app = app
        end

        def call(env)
          if env[:machine].provider_config.qemu_use_session
            @app.call(env)
            return
          end

          # If there were some networks created for this machine, in machines
          # data directory, created_networks file holds UUIDs of each network.
          created_networks_file = env[:machine].data_dir + 'created_networks'

          @logger.info 'Checking if any networks were created'
          # If created_networks file doesn't exist, there are no networks we
          # need to remove.
          unless File.exist?(created_networks_file)
            env[:machine].id = nil
            return @app.call(env)
          end

          @logger.info 'File with created networks exists'

          # Iterate over each created network UUID and try to remove it.
          created_networks = []
          file = File.open(created_networks_file, 'r')
          file.readlines.each do |network_uuid|
            @logger.info "Checking for #{network_uuid}"
            # lookup_network_by_uuid throws same exception
            # if there is an error or if the network just doesn't exist
            begin
              libvirt_network = env[:machine].provider.driver.connection.client.lookup_network_by_uuid(
                network_uuid
              )
            rescue Libvirt::RetrieveError => e
              # this network is already destroyed, so move on
              if e.message =~ /Network not found/
                @logger.info 'It is already undefined'
                next
              # some other error occured, so raise it again
              else
                raise e
              end
            end

            # Skip removing if network has still active connections.
            xml = Nokogiri::XML(libvirt_network.xml_desc)
            connections = xml.xpath('/network/@connections').first
            unless connections.nil?
              @logger.info 'Still has connections so will not undefine'
              created_networks << network_uuid
              next
            end

            # Shutdown network first.
            # Undefine network.
            begin
              libvirt_network.destroy
              libvirt_network.undefine
              @logger.info 'Undefined it'
            rescue => e
              raise Errors::DestroyNetworkError,
                    network_name: libvirt_network.name,
                    error_message: e.message
            end
          end
          file.close

          # Update status of created networks after removing some/all of them.
          # Not sure why we are doing this, something else seems to always delete the file
          if !created_networks.empty?
            File.open(created_networks_file, 'w') do |file|
              @logger.info 'Writing new created_networks file'
              created_networks.each do |network_uuid|
                file.puts network_uuid
              end
            end
          else
            @logger.info 'Deleting created_networks file'
            File.delete(created_networks_file)
          end

          env[:machine].id = nil
          @app.call(env)
        end
      end
    end
  end
end
