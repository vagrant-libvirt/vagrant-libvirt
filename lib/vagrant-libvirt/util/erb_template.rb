module VagrantPlugins
  module ProviderLibvirt
    module Util
      module ErbTemplate
        # TODO: remove and use nokogiri builder
        def to_xml(template_name = nil, data = binding)
          erb = template_name || self.class.to_s.split('::').last.downcase
          path = File.join(File.dirname(__FILE__), '..', 'templates')
          template = "#{erb}.xml"

          # TODO: according to erubis documentation, we should rather use evaluate and forget about
          # binding since the template may then change variables values
          Vagrant::Util::TemplateRenderer.render_with(:render, template, template_root: path) do |renderer|
            iv = data.eval ("instance_variables.collect {|i| [i, instance_variable_get(i.to_sym)]}")
            iv.each {|k, v| renderer.instance_variable_set(k, v)}
          end
        end
      end
    end
  end
end
