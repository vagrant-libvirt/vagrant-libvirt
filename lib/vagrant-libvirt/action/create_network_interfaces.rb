require 'log4r'

module VagrantPlugins
  module Libvirt
    module Action

      # Create network interfaces for domain, before domain is running.
      class CreateNetworkInterfaces
        include VagrantPlugins::Libvirt::Util::ErbTemplate

        def initialize(app, env)
          @logger = Log4r::Logger.new("vagrant_libvirt::action::create_network_interfaces")
          @app = app
        end

        def call(env)
          # Get domain first.
          begin
            domain = env[:libvirt_compute].client.lookup_domain_by_uuid(
              env[:machine].id.to_s)
          rescue => e
            raise Errors::NoDomainError,
              :error_message => e.message
          end

          # Setup list of interfaces before creating them
          adapters = []

          # Assign main interface for provisioning to first slot.
          # Use network 'default' as network for ssh connecting and
          # machine provisioning. This should be maybe configurable in
          # Vagrantfile in future.
          adapters[0] = 'default'

          env[:machine].config.vm.networks.each do |type, options|
            # Other types than bridged are not supported for now.
            next if type != :bridged

            network_name = 'default'
            network_name = options[:bridge] if options[:bridge]

            if options[:adapter]
              if adapters[options[:adapter]]
                raise Errors::InterfaceSlotNotAvailable
              end

              adapters[options[:adapter].to_i] = network_name
            else
              empty_slot = find_empty(adapters, start=1)
              raise Errors::InterfaceSlotNotAvailable if empty_slot == nil

              adapters[empty_slot] = network_name
            end           
          end

          # Create each interface as new domain device
          adapters.each_with_index do |network_name, slot_number|
            @iface_number = slot_number
            @network_name = network_name
            @logger.info("Creating network interface eth#{@iface_number}")
            begin
              domain.attach_device(to_xml('interface'))
            rescue => e
              raise Errors::AttachDeviceError,
                :error_message => e.message
            end
          end

          @app.call(env)
        end

        private

        def find_empty(array, start=0, stop=8)
          for i in start..stop
            return i if !array[i]
          end
          return nil
        end
      end

    end
  end
end

