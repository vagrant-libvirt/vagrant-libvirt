# frozen_string_literal: true

require 'log4r'

module VagrantPlugins
  module ProviderLibvirt
    module Action
      # Halt the domain.
      class HaltDomain
        def initialize(app, _env)
          @logger = Log4r::Logger.new('vagrant_libvirt::action::halt_domain')
          @app = app
        end

        def call(env)
          domain = env[:machine].provider.driver.connection.servers.get(env[:machine].id.to_s)
          if env[:machine].state.id == :running
            env[:ui].info(I18n.t('vagrant_libvirt.halt_domain'))
            domain.poweroff
          end

          @app.call(env)
        end
      end
    end
  end
end
