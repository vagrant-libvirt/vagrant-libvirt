require 'vagrant'

module VagrantPlugins
  module ProviderLibvirt
    autoload :Driver, 'vagrant-libvirt/driver'

    # This is the base class for a provider for the V2 API. A provider
    # is responsible for creating compute resources to match the
    # needs of a Vagrant-configured system.
    class Provider < Vagrant.plugin('2', :provider)
      def initialize(machine)
        @machine = machine
        raise 'REQUIRE USE RUBY >= 1.9.3 VERSION' if RUBY_VERSION < '1.9.3'
      end

      # This should return an action callable for the given name.
      def action(name)
        # Attempt to get the action method from the Action class if it
        # exists, otherwise return nil to show that we don't support the
        # given action.
        action_method = "action_#{name}"
        return Action.send(action_method) if Action.respond_to?(action_method)
        nil
      end

      def driver
        return @driver if @driver

        @driver = Driver.new(@machine)
      end

      # This method is called if the underying machine ID changes. Providers
      # can use this method to load in new data for the actual backing
      # machine or to realize that the machine is now gone (the ID can
      # become `nil`).
      def machine_id_changed; end

      # This should return a hash of information that explains how to
      # SSH into the machine. If the machine is not at a point where
      # SSH is even possible, then `nil` should be returned.
      def ssh_info
        # Return the ssh_info if already retrieved otherwise call the driver
        # and save the result.
        #
        # Ssh info has following format..
        #
        # {
        #  :host => "1.2.3.4",
        #  :port => "22",
        #  :username => "mitchellh",
        #  :private_key_path => "/path/to/my/key"
        # }
        # note that modifing @machine.id or accessing @machine.state is not
        # thread safe, so be careful to avoid these here as this method may
        # be called from other threads of execution.
        return nil if state.id != :running

        ip = driver.get_ipaddress(@machine)

        # if can't determine the IP, just return nil and let the core
        # deal with it, similar to the docker provider
        return nil unless ip

        ssh_info = {
          host: ip,
          port: @machine.config.ssh.guest_port,
          forward_agent: @machine.config.ssh.forward_agent,
          forward_x11: @machine.config.ssh.forward_x11
        }

        if @machine.provider_config.connect_via_ssh
          ssh_info[:proxy_command] =
            "ssh '#{@machine.provider_config.host}' " \
            "-l '#{@machine.provider_config.username}' " \
            "-i '#{@machine.provider_config.id_ssh_key_file}' " \
            'nc %h %p'

        end

        ssh_info
      end

      def mac_addresses
        # Run a custom action called "read_mac_addresses" which will return
        # a list of mac addresses used by the machine. The returned data will
        # be in the following format:
        #
        # {
        #   <ADAPTER_ID>: <MAC>
        # }
        env = @machine.action('read_mac_addresses')
        env[:machine_mac_addresses]
      end

      # This should return the state of the machine within this provider.
      # The state must be an instance of {MachineState}.
      def state
        state_id = nil
        state_id = :not_created unless @machine.id
        state_id = :not_created if
          !state_id && (!@machine.id || !driver.created?(@machine.id))
        # Query the driver for the current state of the machine
        state_id = driver.state(@machine) if @machine.id && !state_id
        state_id = :unknown unless state_id

        # This is a special pseudo-state so that we don't set the
        # NOT_CREATED_ID while we're setting up the machine. This avoids
        # clearing the data dir.
        state_id = :preparing if @machine.id == 'preparing'

        # Get the short and long description
        short = state_id.to_s.tr('_', ' ')
        long  = I18n.t("vagrant_libvirt.states.#{state_id}")

        # If we're not created, then specify the special ID flag
        if state_id == :not_created
          state_id = Vagrant::MachineState::NOT_CREATED_ID
        end

        # Return the MachineState object
        Vagrant::MachineState.new(state_id, short, long)
      end

      def to_s
        id = @machine.id.nil? ? 'new' : @machine.id
        "Libvirt (#{id})"
      end
    end
  end
end
