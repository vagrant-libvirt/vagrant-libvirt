# frozen_string_literal: true

require 'vagrant-spec/acceptance/isolated_environment'
require 'vagrant-spec/subprocess'
require 'vagrant-spec/which'

module VagrantPlugins
  module VagrantLibvirt
    module Spec
      class AcceptanceIsolatedEnvironment < Vagrant::Spec::AcceptanceIsolatedEnvironment
        # Executes a command in the context of this isolated environment.
        # Any command executed will therefore see our temporary directory
        # as the home directory.
        #
        # If the command has been defined with a special path, then the
        # command will be replaced with the full path to that command.
        def execute(command, *args, **options)
          # Create the command
          command = replace_command(command)
          # Use provided command if it is a valid executable
          if !File.executable?(command)
            # If it's not a valid executable, search for vagrant
            command = Vagrant::Spec::Which.which(command)
          end

          # Build up the options
          options[:env] = @env.merge(options.delete(:extra_env) || {})
          options[:notify] = [:stdin, :stderr, :stdout]
          options[:workdir] = @workdir.to_s

          # Execute, logging out the stdout/stderr as we get it
          @logger.info("Executing: #{[command].concat(args).inspect}")
          Vagrant::Spec::Subprocess.execute(command, *args, **options) do |type, data|
            @logger.debug("#{type}: #{data}") if type == :stdout || type == :stderr
            yield type, data if block_given?
          end
        end
      end
    end
  end
end
