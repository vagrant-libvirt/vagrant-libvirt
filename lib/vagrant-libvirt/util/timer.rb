# frozen_string_literal: true

module VagrantPlugins
  module ProviderLibvirt
    module Util
      class Timer
        # A basic utility method that times the execution of the given
        # block and returns it.
        def self.time
          start_time = Time.now.to_f
          yield
          end_time = Time.now.to_f

          end_time - start_time
        end
      end
    end
  end
end
