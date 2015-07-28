require 'pathname'
require 'vagrant-libvirt/plugin'

module VagrantPlugins
  module ProviderLibvirt
    lib_path = Pathname.new(File.expand_path('../vagrant-libvirt', __FILE__))
    autoload :Action, lib_path.join('action')
    autoload :Errors, lib_path.join('errors')
    autoload :Util, lib_path.join('util')

    def self.source_root
      @source_root ||= Pathname.new(File.expand_path('../../', __FILE__))
    end
  end
end
