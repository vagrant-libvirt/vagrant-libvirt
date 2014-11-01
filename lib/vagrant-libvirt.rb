require 'pathname'
require 'vagrant-libvirt/plugin'

module VagrantPlugins
  module ProviderLibvirt
    lib_path = Pathname.new(File.expand_path('../vagrant-libvirt', __FILE__))
    autoload :Action, lib_path.join('action')
    autoload :Errors, lib_path.join('errors')
    autoload :Util, lib_path.join('util')

    # Hold connection handler so there is no need to connect more times than
    # one. This can be annoying when there are more machines to create, or when
    # doing state action first and then some other.
    #
    # TODO Don't sure if this is the best solution
    @@libvirt_connection = nil
    def self.libvirt_connection
      @@libvirt_connection
    end

    def self.libvirt_connection=(conn)
      @@libvirt_connection = conn
    end

    def self.source_root
      @source_root ||= Pathname.new(File.expand_path('../../', __FILE__))
    end
  end
end
