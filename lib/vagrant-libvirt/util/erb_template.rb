require 'erb'

module VagrantPlugins
  module ProviderLibvirt
    module Util
      module ErbTemplate

        # Taken from fog source.
        def to_xml template_name = nil
          erb = template_name || self.class.to_s.split("::").last.downcase
          path = File.join(File.dirname(__FILE__), "..", "templates",
                           "#{erb}.xml.erb")
          template = File.read(path)
          ERB.new(template, nil, '-').result(binding)
        end
 
      end
    end
  end
end

