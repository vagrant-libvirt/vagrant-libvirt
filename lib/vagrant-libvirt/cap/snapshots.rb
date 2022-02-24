module VagrantPlugins
  module ProviderLibvirt
    module Cap
      class Snapshots
        def self.snapshot_list(machine)
          return if machine.state.id == :not_created
          machine.provider.driver.list_snapshots(machine.id)
        end
      end
    end
  end
end
