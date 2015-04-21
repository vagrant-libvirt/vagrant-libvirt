require 'log4r'

module VagrantPlugins
  module ProviderLibvirt
    module Action
      # This action reads the state of the machine and puts it in the
      # `:machine_state_id` key in the environment.
      class ReadState
        def initialize(app, env)
          @app    = app
          @logger = Log4r::Logger.new('vagrant_libvirt::action::read_state')
        end

        def call(env)
          env[:machine_state_id] = read_state(env[:libvirt_compute], env[:machine])
          @app.call(env)
        end

        def read_state(libvirt, machine)
          return :not_created if machine.id.nil?

          begin
            server = libvirt.servers.get(machine.id)
          rescue Libvirt::RetrieveError => e
            server = nil
            @logger.debug('Machine not found #{e}.')
          end
          # Find the machine
          begin
            # Wait for libvirt to shutdown the domain
            while libvirt.servers.get(machine.id).state.to_sym == :'shutting-down' do
              @logger.info('Waiting on the machine to shut down...')
              sleep 1
            end

            server = libvirt.servers.get(machine.id)

            if server.nil? || server.state.to_sym == :terminated
              # The machine can't be found
              @logger.info('Machine terminated, assuming it got destroyed.')
              machine.id = nil
              return :not_created
            end
          rescue Libvirt::RetrieveError => e
            if e.libvirt_code == ProviderLibvirt::Util::ErrorCodes::VIR_ERR_NO_DOMAIN
              @logger.info("Machine #{machine.id} not found.")
              machine.id = nil
              return :not_created
            else
              raise e
            end
          end

          # Return the state
          return server.state.to_sym
        end
      end
    end
  end
end
