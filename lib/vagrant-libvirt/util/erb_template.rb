require 'erubis'

module VagrantPlugins
  module ProviderLibvirt
    module Util
      module ErbTemplate
        # TODO: remove and use nokogiri builder
        # TODO: might be a chance to use vagrant template system according to https://github.com/mitchellh/vagrant/issues/3231
        def to_xml(template_name = nil, data = binding)
          erb = template_name || self.class.to_s.split('::').last.downcase
          path = File.join(File.dirname(__FILE__), '..', 'templates',
                           "#{erb}.xml.erb")
          template = File.read(path)

          # TODO: according to erubis documentation, we should rather use evaluate and forget about
          # binding since the template may then change variables values
          Erubis::Eruby.new(template, trim: true).result(data)
        end
      end
    end
  end
end
