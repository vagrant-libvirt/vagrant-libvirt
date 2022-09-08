# frozen_string_literal: true

require 'vagrant'

# compatibility fix to define constant not available Vagrant <1.6
::Vagrant::MachineState::NOT_CREATED_ID ||= :not_created

module VagrantPlugins
  module ProviderLibvirt
    module Util
      module Compat
        def self.action_hook_args(name, action)
          # handle different number of arguments for action_hook depending on vagrant version
          if Gem::Version.new(Vagrant::VERSION) >= Gem::Version.new('2.2.6')
            return name, action
          end

          return name
        end
      end
    end
  end
end
