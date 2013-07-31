require 'log4r'
require 'nokogiri'

module VagrantPlugins
  module ProviderLibvirt
    module Action
      # Destroy all networks created for this specific domain. Skip
      # removing if network has still active connections.
      class DestroyNetworks

        def initialize(app, env)
          @logger = Log4r::Logger.new("vagrant_libvirt::action::destroy_networks")
          @app = app
        end

        def call(env)
          # If there were some networks created for this machine, in machines
          # data directory, created_networks file holds UUIDs of each network.
          created_networks_file = env[:machine].data_dir + 'created_networks'

          # If created_networks file doesn't exist, there are no networks we
          # need to remove.
          return @app.call(env) if not File.exist?(created_networks_file)

          # Iterate over each created network UUID and try to remove it.
          created_networks = []
          file = File.open(created_networks_file, 'r')
          file.readlines.each do |network_uuid|
            begin
              libvirt_network = env[:libvirt_compute].client.lookup_network_by_uuid(
                network_uuid)
            rescue
              next
            end

            # Maybe network doesn't exist anymore.
            next if not libvirt_network

            # Skip removing if network has still active connections.
            xml = Nokogiri::XML(libvirt_network.xml_desc)
            connections = xml.xpath('/network/@connections').first
            if connections != nil
              created_networks << network_uuid
              next
            end

            # Shutdown network first.
            begin
              libvirt_network.destroy
            rescue => e
            end

            # Undefine network.
            begin
              libvirt_network.undefine
            rescue => e
              raise Error::DestroyNetworkError,
                :network_name  => libvirt_network.name,
                :error_message => e.message
            end
          end
          file.close

          # Update status of created networks after removing some/all of them.
          if created_networks.length > 0
            File.open(created_networks_file, 'w') do |file|
              created_networks.each do |network_uuid|
                file.puts network_uuid
              end
            end
          else
            File.delete(created_networks_file)
          end

          @app.call(env)
        end
      end
    end
  end
end
