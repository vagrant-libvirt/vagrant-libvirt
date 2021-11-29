# frozen_string_literal: true

module VagrantPlugins
  module ProviderLibvirt
    module Util
      module Ui
        # Since v2.2.8 Vagrant support --no-tty option, which silences
        # progress bars and other interactive elements for cleaner logs
        # in scripts, but requires a slight change in UI object handling.
        # This helper allows the vagrant-libvirt plugin to stay compatible
        # with the older Vagrant versions.
        # See: https://github.com/hashicorp/vagrant/pull/11465/
        def rewriting(ui)
          if ui.respond_to?(:rewriting)
            ui.rewriting {|rw| yield rw}
          else
            yield ui
          end
        end
      end
    end
  end
end

