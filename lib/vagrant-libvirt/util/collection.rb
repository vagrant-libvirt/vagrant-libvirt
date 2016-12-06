module VagrantPlugins
  module ProviderLibvirt
    module Util
      module Collection
        # This method finds a matching _thing_ in a collection of
        # _things_. This works matching if the ID or NAME equals to
        # `name`. Or, if `name` is a regexp, a partial match is chosen
        # as well.
        def self.find_matching(collection, name)
          collection.each do |single|
            return single if single.name == name
          end

          nil
        end
      end
    end
  end
end
