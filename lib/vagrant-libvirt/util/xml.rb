# frozen_string_literal: true

require 'xmlsimple'

module VagrantPlugins
  module ProviderLibvirt
    module Util
      class Xml
        attr_reader :xml

        def initialize(xmlstr)
          @xml = compact_content(XmlSimple.xml_in(xmlstr, {'NormaliseSpace' => 2}))
        end

        def to_str
          XmlSimple.xml_out(@xml)
        end

        def ==(other)
          @xml == other.xml
        end

        private

        # content elements that are empty are preserved by xml-simple and will result
        # in the structures being considered different even if functionality the same
        # strip any empty ones to avoid.
        def compact_content(node)
          if node.is_a?(Array)
            node.map! do |element|
              compact_content(element)
            end
          elsif node.is_a?(Hash)
            if node['content'] and node['content'].empty?
              node.delete('content')
            end
            node.each do |k, v|
              node[k] = compact_content(v)
            end
          else
            return node
          end
        end
      end
    end
  end
end
