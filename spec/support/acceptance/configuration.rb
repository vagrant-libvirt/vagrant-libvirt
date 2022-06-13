# frozen_string_literal: true

require 'vagrant-spec/acceptance/configuration'

module VagrantPlugins
  module VagrantLibvirt
    module Spec
      module Acceptance
        class Configuration < Vagrant::Spec::Acceptance::Configuration
          attr_accessor :clean_on_fail

          def initialize
            super

            @clean_on_fail = true
          end
        end
      end
    end
  end
end
