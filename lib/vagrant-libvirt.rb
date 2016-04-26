require 'pathname'

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

begin
  require 'vagrant'
rescue LoadError
  raise 'The Vagrant Libvirt plugin must be run within Vagrant.'
end

# This is a sanity check to make sure no one is attempting to install
# this into an early Vagrant version.
if Vagrant::VERSION < '1.5.0'
  raise 'The Vagrant Libvirt plugin is only compatible with Vagrant 1.5+'
end

# make sure base module class defined before loading plugin
require 'vagrant-libvirt/plugin'
